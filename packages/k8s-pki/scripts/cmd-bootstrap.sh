# k8s-pki bootstrap — convergent PKI generator.
# Generates missing files, re-encrypts on recipient drift, re-signs leaves within 30d of expiry.

# shellcheck source=/dev/null
source "$K8S_PKI_LIB"

FORCE=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --force)        FORCE=1 ;;
    --dry-run)      DRY_RUN=1 ;;
    --identity-dir) load_identity_dir "$2"; shift ;;
    -h|--help)
      cat <<EOF
Usage: k8s-pki-bootstrap [--force] [--dry-run] [--identity-dir DIR]

Converges PKI state:
  - Generates missing CA, SA, per-host leaf, per-user cert.
  - Re-encrypts any file whose recipients differ from current policy.
  - Re-signs any leaf within 30d of expiry.
  - --force re-signs all leaves regardless of expiry (CAs untouched).
  - --identity-dir adds every file in DIR (or DIR itself if a file) as
    an age identity. Repeat to add more. Falls back to age's default
    identity discovery when unset.
EOF
      exit 0 ;;
    *) die "unknown flag: $1" 2 ;;
  esac
  shift
done

REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) \
  || die "not inside a git repo — run from a flake checkout" 2

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ct_path_for() {
  case "$1" in
    common/*)  printf '%s' "$REPO_ROOT/secrets/${1}.age" ;;
    secrets/*) printf '%s' "$REPO_ROOT/${1}.age" ;;
    *) die "unrecognized policy key: $1" 1 ;;
  esac
}

recips_for() {
  jq -r --arg k "$1" '.recipients[$k] // [] | .[]' "$K8S_PKI_DATA"
}

write_encrypted() {
  # write_encrypted POLICY_KEY SRC_PLAINTEXT_FILE
  local key="$1" src="$2"
  local ct; ct=$(ct_path_for "$key")
  local recips; recips=$(recips_for "$key")
  [ -n "$recips" ] || die "no recipients defined for $key" 1
  if [ "$DRY_RUN" -eq 1 ]; then
    log info "would write $key"
    return
  fi
  mkdir -p "$(dirname "$ct")"
  RECIPIENTS="$recips" age_encrypt_to "$ct" < "$src"
}

reencrypt_in_place() {
  # reencrypt_in_place POLICY_KEY — keeps plaintext, swaps recipient list
  local key="$1"
  local ct; ct=$(ct_path_for "$key")
  local tmp; tmp=$(mktemp)
  age_decrypt_in "$ct" > "$tmp"
  write_encrypted "$key" "$tmp"
  rm -f "$tmp"
}

# decide_action KEY → prints one of GENERATE | REENCRYPT | RESIGN | SKIP
decide_action() {
  local key="$1"
  local ct; ct=$(ct_path_for "$key")

  [ -f "$ct" ] || { echo GENERATE; return; }

  # FORCE only applies to non-common (i.e. leaves/user certs) — CAs never resigned by bootstrap
  if [ "$FORCE" -eq 1 ] && [[ "$key" != common/* ]]; then
    echo RESIGN; return
  fi

  case "$key" in
    *.crt)
      local pt pem secs days
      if ! pt=$(age_decrypt_in "$ct" 2>/dev/null); then
        # Can't decrypt — treat as regenerate
        echo GENERATE; return
      fi
      pem=$(mktemp); printf '%s' "$pt" > "$pem"
      secs=$(pem_expiry_seconds "$pem" 2>/dev/null || echo 0)
      rm -f "$pem"
      days=$((secs / 86400))
      if [ "$days" -lt 30 ] && [[ "$key" != common/* ]]; then
        echo RESIGN; return
      fi ;;
  esac

  # Recipient drift: count comparison (approximate)
  local expected actual en an
  expected=$(recips_for "$key" | sort -u)
  actual=$(age_recipients_of "$ct" | sort -u)
  en=$(printf '%s\n' "$expected" | grep -c . || true)
  an=$(printf '%s\n' "$actual" | grep -c . || true)
  if [ "$en" -ne "$an" ]; then
    echo REENCRYPT; return
  fi
  echo SKIP
}

#####################################################
# PHASE 1 — CAs (3) + SA keypair
#####################################################

gen_or_converge_ca() {
  local ca="$1"
  local crt_key="common/k8s-pki/${ca}.crt"
  local key_key="common/k8s-pki/${ca}.key"

  local a_crt; a_crt=$(decide_action "$crt_key")
  local a_key; a_key=$(decide_action "$key_key")

  if [ "$a_crt" = GENERATE ] || [ "$a_key" = GENERATE ]; then
    log info "GENERATE CA $ca"
    [ "$DRY_RUN" -eq 1 ] && return
    local outdir; outdir=$(mktemp -d)
    mkdir -p "$outdir/$(dirname "$ca")"
    local cn exp
    cn=$(jq -r --arg k "$ca" '.specs.cas[$k].CN' "$K8S_PKI_DATA")
    exp=$(jq -r --arg k "$ca" '.specs.cas[$k].expiry' "$K8S_PKI_DATA")
    cfssl_gen_ca "$ca" "$cn" "$exp" "$outdir"
    write_encrypted "$crt_key" "$outdir/${ca}.pem"
    write_encrypted "$key_key" "$outdir/${ca}-key.pem"
    rm -rf "$outdir"
  else
    [ "$a_crt" = REENCRYPT ] && { log info "RE-ENCRYPT $crt_key"; [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$crt_key"; }
    [ "$a_key" = REENCRYPT ] && { log info "RE-ENCRYPT $key_key"; [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$key_key"; }
    [ "$a_crt" = SKIP ] && log info "skip (current) $crt_key"
    [ "$a_key" = SKIP ] && log info "skip (current) $key_key"
  fi
}

gen_or_converge_sa() {
  local pub_key="common/k8s-pki/sa.pub"
  local key_key="common/k8s-pki/sa.key"
  local ct_pub; ct_pub=$(ct_path_for "$pub_key")
  local ct_key; ct_key=$(ct_path_for "$key_key")

  if [ ! -f "$ct_pub" ] || [ ! -f "$ct_key" ]; then
    log info "GENERATE SA keypair"
    [ "$DRY_RUN" -eq 1 ] && return
    local bits; bits=$(jq -r '.specs.sa.keyBits' "$K8S_PKI_DATA")
    local tmp; tmp=$(mktemp -d)
    openssl genrsa -out "$tmp/sa.key" "$bits" 2>/dev/null
    openssl rsa -in "$tmp/sa.key" -pubout -out "$tmp/sa.pub" 2>/dev/null
    write_encrypted "$pub_key" "$tmp/sa.pub"
    write_encrypted "$key_key" "$tmp/sa.key"
    rm -rf "$tmp"
  else
    local a_pub; a_pub=$(decide_action "$pub_key")
    local a_key; a_key=$(decide_action "$key_key")
    [ "$a_pub" = REENCRYPT ] && { log info "RE-ENCRYPT $pub_key"; [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$pub_key"; }
    [ "$a_key" = REENCRYPT ] && { log info "RE-ENCRYPT $key_key"; [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$key_key"; }
    [ "$a_pub" = SKIP ] && log info "skip (current) $pub_key"
    [ "$a_key" = SKIP ] && log info "skip (current) $key_key"
  fi
}

prepare_ca() {
  # Decrypt a CA keypair into $WORK/<ca>/ca.{pem,-key.pem}; prints path prefix (no .pem/-key.pem)
  local ca="$1"
  local outdir="$WORK/$ca"
  if [ -d "$outdir" ]; then
    printf '%s' "$outdir/ca"
    return
  fi
  mkdir -p "$outdir"
  age_decrypt_in "$(ct_path_for "common/k8s-pki/${ca}.crt")" > "$outdir/ca.pem"
  age_decrypt_in "$(ct_path_for "common/k8s-pki/${ca}.key")" > "$outdir/ca-key.pem"
  printf '%s' "$outdir/ca"
}

#####################################################
# PHASE 2 — per-host leaves
#####################################################

iter_host_leaves() {
  jq -r '
    .hosts as $H | .specs.leaves as $L |
    $H | to_entries[] | . as $he |
    $L | to_entries[] |
    select(.value.scope == "all" or .value.scope == $he.value.role) |
    "\($he.key)\t\(.key)"
  ' "$K8S_PKI_DATA"
}

gen_host_leaf() {
  local hostName="$1" leaf="$2"
  local crt_key="secrets/${hostName}/system/homelab-k8s/${leaf}.crt"
  local key_key="secrets/${hostName}/system/homelab-k8s/${leaf}.key"

  local a_crt; a_crt=$(decide_action "$crt_key")
  local a_key; a_key=$(decide_action "$key_key")

  case "${a_crt}:${a_key}" in
    GENERATE:*|*:GENERATE|RESIGN:*|*:RESIGN)
      log info "GENERATE leaf $hostName/$leaf"
      [ "$DRY_RUN" -eq 1 ] && return
      local hostJson leafJson signer cn cn_raw hosts_arr_json
      hostJson=$(jq -c --arg h "$hostName" '.hosts[$h]' "$K8S_PKI_DATA")
      leafJson=$(jq -c --arg l "$leaf"     '.specs.leaves[$l]' "$K8S_PKI_DATA")
      signer=$(jq -r '.signer' <<<"$leafJson")
      cn_raw=$(jq -r '.CN' <<<"$leafJson")
      cn=$(printf '%s' "$cn_raw" | tmpl_host "$hostJson")
      local org_raw org
      org_raw=$(jq -r '.O // ""' <<<"$leafJson")
      org=$(printf '%s' "$org_raw" | tmpl_host "$hostJson")
      hosts_arr_json=$(jq -c '.hosts // []' <<<"$leafJson" \
        | jq -r '.[]' | tmpl_host "$hostJson" | jq -R . | jq -s .)
      local expiry profile_name profile_json
      expiry=$(jq -r '.expiry' <<<"$leafJson")
      profile_name=$(jq -r '.profile' <<<"$leafJson")
      profile_json=$(jq -c --arg p "$profile_name" '.specs.profiles[$p]' "$K8S_PKI_DATA")

      local ca_prefix; ca_prefix=$(prepare_ca "$signer")
      local outdir; outdir=$(mktemp -d)
      mkdir -p "$outdir/$(dirname "$leaf")"
      cfssl_gen_leaf "$leaf" "$cn" "$org" "$ca_prefix" "$profile_json" "$hosts_arr_json" "$expiry" "$outdir"
      write_encrypted "$crt_key" "$outdir/${leaf}.pem"
      write_encrypted "$key_key" "$outdir/${leaf}-key.pem"
      rm -rf "$outdir"
      ;;
    REENCRYPT:*)
      log info "RE-ENCRYPT $crt_key"
      [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$crt_key"
      [ "$a_key" = REENCRYPT ] && { log info "RE-ENCRYPT $key_key"; [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$key_key"; }
      ;;
    *:REENCRYPT)
      log info "RE-ENCRYPT $key_key"
      [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$key_key"
      ;;
    SKIP:SKIP)
      log info "skip (current) $hostName/$leaf"
      ;;
    *)
      log warn "unhandled action pair $a_crt:$a_key for $hostName/$leaf"
      ;;
  esac
}

#####################################################
# PHASE 3 — per-user certs
#####################################################

gen_user_certs() {
  local userKey="$1"
  local userJson; userJson=$(jq -c --arg k "$userKey" '.users[$k]' "$K8S_PKI_DATA")
  local uname uhost
  uname=$(jq -r '.name' <<<"$userJson")
  uhost=$(jq -r '.host' <<<"$userJson")

  local prefix="secrets/${uhost}/home/${uname}/homelab-k8s"
  local ca_user_key="${prefix}/ca.crt"
  local crt_key="${prefix}/cluster-admin.crt"
  local key_key="${prefix}/cluster-admin.key"

  # Copy common/k8s-pki/ca.crt plaintext into user's dir, re-encrypted to user recipients
  local a_ca; a_ca=$(decide_action "$ca_user_key")
  case "$a_ca" in
    GENERATE)
      log info "COPY ca.crt → $userKey"
      [ "$DRY_RUN" -eq 1 ] || {
        local tmp; tmp=$(mktemp)
        age_decrypt_in "$(ct_path_for common/k8s-pki/ca.crt)" > "$tmp"
        write_encrypted "$ca_user_key" "$tmp"
        rm -f "$tmp"
      } ;;
    REENCRYPT)
      log info "RE-ENCRYPT $ca_user_key"
      [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$ca_user_key" ;;
    SKIP) log info "skip (current) $ca_user_key" ;;
  esac

  local a_crt; a_crt=$(decide_action "$crt_key")
  local a_key; a_key=$(decide_action "$key_key")
  case "${a_crt}:${a_key}" in
    GENERATE:*|*:GENERATE|RESIGN:*|*:RESIGN)
      log info "GENERATE cluster-admin for $userKey"
      [ "$DRY_RUN" -eq 1 ] && return
      local ca_prefix; ca_prefix=$(prepare_ca "ca")
      local userSpec; userSpec=$(jq -c '.specs.users["cluster-admin"]' "$K8S_PKI_DATA")
      local cn org expiry profile_json
      cn=$(jq -r '.CN' <<<"$userSpec")
      org=$(jq -r '.O // ""' <<<"$userSpec")
      expiry=$(jq -r '.expiry' <<<"$userSpec")
      profile_json=$(jq -c '.specs.profiles.client' "$K8S_PKI_DATA")

      local outdir; outdir=$(mktemp -d)
      local csr cfg
      csr="$outdir/csr.json"; cfg="$outdir/cfg.json"
      jq -n --arg cn "$cn" --arg o "$org" \
        '{CN:$cn, hosts:[], names:[{O:$o}], key:{algo:"rsa",size:2048}}' > "$csr"
      jq -n --argjson p "$profile_json" --arg e "$expiry" \
        '{signing:{default:{expiry:$e}, profiles:{default:($p + {expiry:$e})}}}' > "$cfg"
      cfssl gencert -ca="$ca_prefix.pem" -ca-key="$ca_prefix-key.pem" \
        -config="$cfg" -profile=default "$csr" \
        | cfssljson -bare "$outdir/cluster-admin"
      write_encrypted "$crt_key" "$outdir/cluster-admin.pem"
      write_encrypted "$key_key" "$outdir/cluster-admin-key.pem"
      rm -rf "$outdir"
      ;;
    REENCRYPT:*)
      log info "RE-ENCRYPT $crt_key"
      [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$crt_key"
      [ "$a_key" = REENCRYPT ] && { log info "RE-ENCRYPT $key_key"; [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$key_key"; }
      ;;
    *:REENCRYPT)
      log info "RE-ENCRYPT $key_key"
      [ "$DRY_RUN" -eq 1 ] || reencrypt_in_place "$key_key"
      ;;
    SKIP:SKIP)
      log info "skip (current) $userKey/cluster-admin"
      ;;
  esac
}

#####################################################

for ca in $(jq -r '.specs.cas | keys[]' "$K8S_PKI_DATA"); do
  gen_or_converge_ca "$ca"
done
gen_or_converge_sa

while IFS=$'\t' read -r hostName leaf; do
  [ -z "$hostName" ] && continue
  gen_host_leaf "$hostName" "$leaf"
done < <(iter_host_leaves)

for u in $(jq -r '.users | keys[]' "$K8S_PKI_DATA"); do
  gen_user_certs "$u"
done

log info "bootstrap complete"

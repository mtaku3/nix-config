# k8s-pki renew — re-sign leaves only. CA files never read-modify-written.

# shellcheck source=/dev/null
source "$K8S_PKI_LIB"

FORCE=0 DRY_RUN=0
SCOPE_HOST="" SCOPE_USER="" SCOPE_CERT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --force)   FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --host)    SCOPE_HOST="$2"; shift ;;
    --user)    SCOPE_USER="$2"; shift ;;
    --cert)    SCOPE_CERT="$2"; shift ;;
    -h|--help)
      cat <<EOF
Usage: k8s-pki-renew [--host H] [--user U] [--cert NAME] [--force] [--dry-run]

Re-signs leaves within 30d of expiry (or all leaves with --force).
CAs are never touched. Does not repair recipient drift — use 'bootstrap' for that.
EOF
      exit 0 ;;
    *) die "unknown flag: $1" 2 ;;
  esac
  shift
done

REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) \
  || die "not inside a git repo" 2

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ct_path_for() {
  case "$1" in
    common/*)  printf '%s' "$REPO_ROOT/secrets/${1}.age" ;;
    secrets/*) printf '%s' "$REPO_ROOT/${1}.age" ;;
    *) die "unrecognized key: $1" 1 ;;
  esac
}

recips_for() { jq -r --arg k "$1" '.recipients[$k] // [] | .[]' "$K8S_PKI_DATA"; }

write_encrypted() {
  local key="$1" src="$2"
  local ct; ct=$(ct_path_for "$key")
  local recips; recips=$(recips_for "$key")
  [ -n "$recips" ] || die "no recipients for $key" 1
  [ "$DRY_RUN" -eq 1 ] && { log info "would write $key"; return; }
  mkdir -p "$(dirname "$ct")"
  RECIPIENTS="$recips" age_encrypt_to "$ct" < "$src"
}

prepare_ca() {
  local ca="$1"
  local outdir="$WORK/$ca"
  if [ -d "$outdir" ]; then
    printf '%s' "$outdir/ca"; return
  fi
  mkdir -p "$outdir"
  age_decrypt_in "$(ct_path_for "common/k8s-pki/${ca}.crt")" > "$outdir/ca.pem"
  age_decrypt_in "$(ct_path_for "common/k8s-pki/${ca}.key")" > "$outdir/ca-key.pem"
  printf '%s' "$outdir/ca"
}

needs_renew() {
  # needs_renew CIPHERTEXT_PATH → exit 0 if near expiry or FORCE
  local ct="$1"
  [ -f "$ct" ] || return 1
  local pt pem secs days
  if ! pt=$(age_decrypt_in "$ct" 2>/dev/null); then
    return 1
  fi
  pem=$(mktemp); printf '%s' "$pt" > "$pem"
  secs=$(pem_expiry_seconds "$pem" 2>/dev/null || echo 0)
  rm -f "$pem"
  days=$((secs / 86400))
  if [ "$FORCE" -eq 1 ] || [ "$days" -lt 30 ]; then
    return 0
  fi
  return 1
}

#####################################################
# Host leaves
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

renew_host_leaf() {
  local hostName="$1" leaf="$2"
  [ -n "$SCOPE_USER" ] && return
  [ -n "$SCOPE_HOST" ] && [ "$SCOPE_HOST" != "$hostName" ] && return
  [ -n "$SCOPE_CERT" ] && [ "$SCOPE_CERT" != "$leaf" ] && return

  local crt_key="secrets/${hostName}/system/homelab-k8s/${leaf}.crt"
  local key_key="secrets/${hostName}/system/homelab-k8s/${leaf}.key"
  local ct_crt; ct_crt=$(ct_path_for "$crt_key")

  needs_renew "$ct_crt" || return

  log info "RESIGN $hostName/$leaf"
  [ "$DRY_RUN" -eq 1 ] && return

  local hostJson leafJson signer cn_raw cn hosts_arr_json expiry profile_name profile_json
  hostJson=$(jq -c --arg h "$hostName" '.hosts[$h]' "$K8S_PKI_DATA")
  leafJson=$(jq -c --arg l "$leaf"     '.specs.leaves[$l]' "$K8S_PKI_DATA")
  signer=$(jq -r '.signer' <<<"$leafJson")
  cn_raw=$(jq -r '.CN' <<<"$leafJson")
  cn=$(printf '%s' "$cn_raw" | tmpl_host "$hostJson")
  hosts_arr_json=$(jq -c '.hosts // []' <<<"$leafJson" \
    | jq -r '.[]' | tmpl_host "$hostJson" | jq -R . | jq -s .)
  expiry=$(jq -r '.expiry' <<<"$leafJson")
  profile_name=$(jq -r '.profile' <<<"$leafJson")
  profile_json=$(jq -c --arg p "$profile_name" '.specs.profiles[$p]' "$K8S_PKI_DATA")

  local ca_prefix; ca_prefix=$(prepare_ca "$signer")
  local outdir; outdir=$(mktemp -d)
  mkdir -p "$outdir/$(dirname "$leaf")"
  cfssl_gen_leaf "$leaf" "$cn" "$ca_prefix" "$profile_json" "$hosts_arr_json" "$expiry" "$outdir"
  write_encrypted "$crt_key" "$outdir/${leaf}.pem"
  write_encrypted "$key_key" "$outdir/${leaf}-key.pem"
  rm -rf "$outdir"
}

#####################################################
# User certs
#####################################################

renew_user_cert() {
  local userKey="$1"
  [ -n "$SCOPE_HOST" ] && return
  [ -n "$SCOPE_USER" ] && [ "$SCOPE_USER" != "$userKey" ] && return
  [ -n "$SCOPE_CERT" ] && [ "$SCOPE_CERT" != "cluster-admin" ] && return

  local userJson uname uhost
  userJson=$(jq -c --arg k "$userKey" '.users[$k]' "$K8S_PKI_DATA")
  uname=$(jq -r '.name' <<<"$userJson")
  uhost=$(jq -r '.host' <<<"$userJson")

  local crt_key="secrets/${uhost}/home/${uname}/homelab-k8s/cluster-admin.crt"
  local key_key="secrets/${uhost}/home/${uname}/homelab-k8s/cluster-admin.key"
  local ct_crt; ct_crt=$(ct_path_for "$crt_key")

  needs_renew "$ct_crt" || return

  log info "RESIGN $userKey/cluster-admin"
  [ "$DRY_RUN" -eq 1 ] && return

  local ca_prefix; ca_prefix=$(prepare_ca "ca")
  local userSpec cn org expiry profile_json
  userSpec=$(jq -c '.specs.users["cluster-admin"]' "$K8S_PKI_DATA")
  cn=$(jq -r '.CN' <<<"$userSpec")
  org=$(jq -r '.O // ""' <<<"$userSpec")
  expiry=$(jq -r '.expiry' <<<"$userSpec")
  profile_json=$(jq -c '.specs.profiles.client' "$K8S_PKI_DATA")

  local outdir; outdir=$(mktemp -d)
  jq -n --arg cn "$cn" --arg o "$org" \
    '{CN:$cn, hosts:[], names:[{O:$o}], key:{algo:"rsa",size:2048}}' > "$outdir/csr.json"
  jq -n --argjson p "$profile_json" --arg e "$expiry" \
    '{signing:{default:{expiry:$e}, profiles:{default:($p + {expiry:$e})}}}' > "$outdir/cfg.json"
  cfssl gencert -ca="$ca_prefix.pem" -ca-key="$ca_prefix-key.pem" \
    -config="$outdir/cfg.json" -profile=default "$outdir/csr.json" \
    | cfssljson -bare "$outdir/cluster-admin"
  write_encrypted "$crt_key" "$outdir/cluster-admin.pem"
  write_encrypted "$key_key" "$outdir/cluster-admin-key.pem"
  rm -rf "$outdir"
}

#####################################################

while IFS=$'\t' read -r hostName leaf; do
  [ -z "$hostName" ] && continue
  renew_host_leaf "$hostName" "$leaf"
done < <(iter_host_leaves)

for u in $(jq -r '.users | keys[]' "$K8S_PKI_DATA"); do
  renew_user_cert "$u"
done

log info "renew complete"

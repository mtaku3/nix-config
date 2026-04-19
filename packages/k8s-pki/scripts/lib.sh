# Shared helpers for k8s-pki shell commands.
# Sourced by cmd-*.sh; exercised by tests/lib.bats.

set -euo pipefail

# die MSG [CODE] — print error to stderr and exit
die() {
  local msg="$1"
  local code="${2:-1}"
  printf 'error: %s\n' "$msg" >&2
  exit "$code"
}

# log LEVEL MSG... — structured stderr log line
log() {
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*" >&2
}

# pem_expiry_seconds PATH — seconds from now until notAfter (negative if expired)
pem_expiry_seconds() {
  local path="$1"
  local not_after now exp_epoch
  not_after=$(openssl x509 -in "$path" -noout -enddate | sed 's/^notAfter=//')
  now=$(date -u +%s)
  exp_epoch=$(date -u -d "$not_after" +%s)
  echo $((exp_epoch - now))
}

# age_recipients_of PATH — print recipient header lines from ciphertext (header only)
age_recipients_of() {
  local path="$1"
  awk '
    /^-----BEGIN AGE ENCRYPTED FILE-----/ { in_armor=1; next }
    /^-----END AGE ENCRYPTED FILE-----/   { exit }
    /^--- / { exit }
    /^-> / { sub(/^-> /, ""); print }
  ' "$path"
}

# recipient_set_eq A B — exit 0 iff sorted-unique sets are equal (newline-separated input)
recipient_set_eq() {
  local a b
  a=$(printf '%s\n' "$1" | sort -u)
  b=$(printf '%s\n' "$2" | sort -u)
  [ "$a" = "$b" ]
}

# age_encrypt_to FILE_OUT — encrypt stdin to env var $RECIPIENTS (newline-separated pubkeys)
age_encrypt_to() {
  local out="$1"
  local -a args=()
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    args+=(-r "$r")
  done <<< "${RECIPIENTS:-}"
  [ "${#args[@]}" -gt 0 ] || die "age_encrypt_to called with empty RECIPIENTS" 1
  age "${args[@]}" -o "$out"
}

# is_age_identity_file PATH — heuristically accept native-age or OpenSSH private keys.
# Reads only the first 4KB to sniff the header. Exit 0 if plausible, 1 otherwise.
is_age_identity_file() {
  local f="$1"
  head -c 4096 "$f" 2>/dev/null \
    | grep -aqE 'AGE-SECRET-KEY-1|-----BEGIN (OPENSSH|RSA|EC) PRIVATE KEY-----|-----BEGIN PRIVATE KEY-----'
}

# load_identity_dir DIR — append every regular file in DIR (non-recursive) to AGENIX_IDENTITIES.
# Accepts a file path as well. Skips silently if DIR is empty.
load_identity_dir() {
  local path="$1"
  [ -n "$path" ] || return 0
  [ -e "$path" ] || die "identity path does not exist: $path" 2
  local entries=""
  if [ -d "$path" ]; then
    local f
    for f in "$path"/*; do
      [ -f "$f" ] || continue
      is_age_identity_file "$f" || continue
      entries="${entries}${f}"$'\n'
    done
  else
    entries="${path}"$'\n'
  fi
  [ -n "$entries" ] || die "no identity files found in: $path" 2
  log info "loaded identities from $path:"
  printf '%s' "$entries" | sed 's/^/  /' >&2
  if [ -n "${AGENIX_IDENTITIES:-}" ]; then
    AGENIX_IDENTITIES="${AGENIX_IDENTITIES}"$'\n'"${entries%$'\n'}"
  else
    AGENIX_IDENTITIES="${entries%$'\n'}"
  fi
  export AGENIX_IDENTITIES
}

# age_decrypt_in FILE — decrypt ciphertext to stdout.
# Identities are read from $AGENIX_IDENTITIES (newline-separated paths).
# If unset, relies on age's default identity discovery.
age_decrypt_in() {
  local in="$1"
  local -a args=()
  if [ -n "${AGENIX_IDENTITIES:-}" ]; then
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      args+=(-i "$id")
    done <<< "$AGENIX_IDENTITIES"
  fi
  age -d "${args[@]}" "$in"
}

# jq_data EXPR — run jq over $K8S_PKI_DATA
jq_data() {
  jq -r "$1" "$K8S_PKI_DATA"
}

# tmpl_host HOST_JSON — substitute {host.*} tokens in stdin using HOST_JSON
tmpl_host() {
  local host_json="$1"
  local name ip master
  name=$(printf '%s' "$host_json" | jq -r '.name')
  ip=$(printf '%s' "$host_json" | jq -r '.advertiseIP')
  master=$(printf '%s' "$host_json" | jq -r '.masterAddress')
  sed -e "s/{host.name}/$name/g" \
      -e "s/{host.advertiseIP}/$ip/g" \
      -e "s/{host.masterAddress}/$master/g"
}

# cfssl_gen_ca NAME CN EXPIRY OUTDIR — self-signed CA keypair as OUTDIR/NAME.pem and OUTDIR/NAME-key.pem
cfssl_gen_ca() {
  local name="$1" cn="$2" expiry="$3" outdir="$4"
  local csr
  csr=$(mktemp)
  jq -n --arg cn "$cn" --arg expiry "$expiry" '{
    CN: $cn,
    key: { algo: "rsa", size: 2048 },
    ca: { expiry: $expiry }
  }' > "$csr"
  mkdir -p "$(dirname "$outdir/$name")"
  cfssl gencert -initca "$csr" | cfssljson -bare "$outdir/$name"
  rm -f "$csr" "$outdir/$name.csr"
}

# cfssl_gen_leaf NAME CN O CA_PREFIX PROFILE_JSON HOSTS_JSON EXPIRY OUTDIR
#   CA_PREFIX points to files <prefix>.pem and <prefix>-key.pem.
#   O may be empty string; if non-empty, added as names[0].O in the CSR.
#   Outputs OUTDIR/NAME.pem and OUTDIR/NAME-key.pem.
cfssl_gen_leaf() {
  local name="$1" cn="$2" org="$3" ca_prefix="$4" profile_json="$5" hosts_json="$6" expiry="$7" outdir="$8"
  local csr cfg
  csr=$(mktemp); cfg=$(mktemp)
  if [ -n "$org" ]; then
    jq -n --arg cn "$cn" --arg o "$org" --argjson hosts "$hosts_json" '{
      CN: $cn,
      hosts: $hosts,
      names: [{O: $o}],
      key: { algo: "rsa", size: 2048 }
    }' > "$csr"
  else
    jq -n --arg cn "$cn" --argjson hosts "$hosts_json" '{
      CN: $cn,
      hosts: $hosts,
      key: { algo: "rsa", size: 2048 }
    }' > "$csr"
  fi
  jq -n --argjson profile "$profile_json" --arg expiry "$expiry" '{
    signing: {
      default: { expiry: $expiry },
      profiles: { default: ($profile + { expiry: $expiry }) }
    }
  }' > "$cfg"
  mkdir -p "$(dirname "$outdir/$name")"
  cfssl gencert \
    -ca="$ca_prefix.pem" -ca-key="$ca_prefix-key.pem" \
    -config="$cfg" -profile=default "$csr" \
    | cfssljson -bare "$outdir/$name"
  rm -f "$csr" "$cfg" "$outdir/$name.csr"
}

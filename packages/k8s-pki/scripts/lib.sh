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

# age_decrypt_in FILE — decrypt ciphertext to stdout via default age identity discovery
age_decrypt_in() {
  local in="$1"
  age -d "$in"
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

# cfssl_gen_leaf NAME CN CA_PREFIX PROFILE_JSON HOSTS_JSON EXPIRY OUTDIR
#   CA_PREFIX points to files <prefix>.pem and <prefix>-key.pem.
#   Outputs OUTDIR/NAME.pem and OUTDIR/NAME-key.pem.
cfssl_gen_leaf() {
  local name="$1" cn="$2" ca_prefix="$3" profile_json="$4" hosts_json="$5" expiry="$6" outdir="$7"
  local csr cfg
  csr=$(mktemp); cfg=$(mktemp)
  jq -n --arg cn "$cn" --argjson hosts "$hosts_json" '{
    CN: $cn,
    hosts: $hosts,
    key: { algo: "rsa", size: 2048 }
  }' > "$csr"
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

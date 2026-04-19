# k8s-pki status — read-only PKI report.
# Exit 0 clean, 3 if drift/missing/stale detected.

# shellcheck source=/dev/null
source "$K8S_PKI_LIB"

# shellcheck disable=SC2034  # VERBOSE reserved for future verbose output
VERBOSE=0
JSON=0

while [ $# -gt 0 ]; do
  # shellcheck disable=SC2034  # VERBOSE reserved for future verbose output
  case "$1" in
    -v|--verbose)   VERBOSE=1 ;;
    --json)         JSON=1 ;;
    --identity-dir) load_identity_dir "$2"; shift ;;
    -h|--help)
      cat <<EOF
Usage: k8s-pki-status [-v|--verbose] [--json] [--identity-dir DIR]

Reports expiry + recipient drift for every PKI ciphertext.
  --identity-dir DIR   extra age identities (file or directory of files)
Exit codes: 0 clean, 3 drift/missing/stale.
EOF
      exit 0 ;;
    *) die "unknown flag: $1" 2 ;;
  esac
  shift
done

REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) \
  || die "not inside a git repo — run from a flake checkout" 2

ct_path_for() {
  case "$1" in
    common/*)  printf '%s' "$REPO_ROOT/secrets/${1}.age" ;;
    secrets/*) printf '%s' "$REPO_ROOT/${1}.age" ;;
    *) die "unrecognized policy key: $1" 1 ;;
  esac
}

# Build the list of expected keys from data.json
# - 8 common files (4 crt + 4 key including sa.pub/sa.key)
# - per-host leaves (scope == role OR scope == "all")
# - per-user certs (ca.crt, cluster-admin.crt, cluster-admin.key)
mapfile -t EXPECTED < <(
  jq -r '
    . as $root |
    ["common/k8s-pki/ca.crt","common/k8s-pki/ca.key",
     "common/k8s-pki/etcd/ca.crt","common/k8s-pki/etcd/ca.key",
     "common/k8s-pki/front-proxy-ca.crt","common/k8s-pki/front-proxy-ca.key",
     "common/k8s-pki/sa.pub","common/k8s-pki/sa.key"] +
    (
      [ $root.hosts | to_entries[] | . as $he |
        ($he.value.role) as $role |
        $root.specs.leaves | to_entries[] |
        select(.value.scope == "all" or .value.scope == $role) |
        ("secrets/\($he.key)/system/homelab-k8s/\(.key).crt",
         "secrets/\($he.key)/system/homelab-k8s/\(.key).key") ]
    ) +
    (
      [ $root.users | to_entries[] | . as $ue |
        ("secrets/\($ue.value.host)/home/\($ue.value.name)/homelab-k8s/ca.crt",
         "secrets/\($ue.value.host)/home/\($ue.value.name)/homelab-k8s/cluster-admin.crt",
         "secrets/\($ue.value.host)/home/\($ue.value.name)/homelab-k8s/cluster-admin.key") ]
    )
    | .[]
  ' "$K8S_PKI_DATA"
)

missing=0
drift=0
stale=0
clean=0
rows=()

for rel in "${EXPECTED[@]}"; do
  ct=$(ct_path_for "$rel")
  status=""
  detail=""

  if [ ! -f "$ct" ]; then
    status="MISSING"
    detail="no file at ${ct#"$REPO_ROOT"/}"
    missing=$((missing + 1))
    rows+=("$(jq -cn --arg p "$rel" --arg s "$status" --arg d "$detail" '{path:$p,status:$s,detail:$d}')")
    continue
  fi

  # Expiry check for .crt files
  case "$rel" in
    *.crt)
      if ! pt=$(age_decrypt_in "$ct" 2>/dev/null); then
        status="NOREAD"; detail="cannot decrypt with current identity"
        rows+=("$(jq -cn --arg p "$rel" --arg s "$status" --arg d "$detail" '{path:$p,status:$s,detail:$d}')")
        continue
      fi
      pem=$(mktemp); printf '%s' "$pt" > "$pem"
      secs=$(pem_expiry_seconds "$pem" 2>/dev/null || echo 0)
      rm -f "$pem"
      days=$((secs / 86400))
      if [ "$secs" -le 0 ]; then
        status="EXPIRED"; detail="expired $((-days))d ago"
        stale=$((stale + 1))
        rows+=("$(jq -cn --arg p "$rel" --arg s "$status" --arg d "$detail" '{path:$p,status:$s,detail:$d}')")
        continue
      elif [ "$days" -lt 7 ]; then
        status="STALE"; detail="expires in ${days}d"
        stale=$((stale + 1))
        rows+=("$(jq -cn --arg p "$rel" --arg s "$status" --arg d "$detail" '{path:$p,status:$s,detail:$d}')")
        continue
      else
        detail="expires in ${days}d"
      fi
      ;;
  esac

  # Recipient-drift check (approximate: compare count only, full pubkey matching not always possible
  #                      because ssh/x25519 recipients don't round-trip textually through age headers)
  expected_list=$(jq -r --arg k "$rel" '.recipients[$k] // [] | .[]' "$K8S_PKI_DATA")
  actual_list=$(age_recipients_of "$ct")
  expected_n=$(printf '%s\n' "$expected_list" | grep -c . || true)
  actual_n=$(printf '%s\n' "$actual_list"  | grep -c . || true)
  if [ "$expected_n" -ne "$actual_n" ]; then
    status="DRIFT"
    detail="recipients: file=$actual_n expected=$expected_n"
    drift=$((drift + 1))
    rows+=("$(jq -cn --arg p "$rel" --arg s "$status" --arg d "$detail" '{path:$p,status:$s,detail:$d}')")
    continue
  fi

  status="OK"
  clean=$((clean + 1))
  rows+=("$(jq -cn --arg p "$rel" --arg s "$status" --arg d "$detail" '{path:$p,status:$s,detail:$d}')")
done

if [ "$JSON" -eq 1 ]; then
  printf '{"files":['
  first=1
  for r in "${rows[@]}"; do
    if [ "$first" -eq 1 ]; then first=0; else printf ','; fi
    printf '%s' "$r"
  done
  printf '],"summary":{"clean":%d,"stale":%d,"drift":%d,"missing":%d}}\n' \
    "$clean" "$stale" "$drift" "$missing"
else
  for r in "${rows[@]}"; do
    p=$(jq -r '.path' <<<"$r")
    s=$(jq -r '.status' <<<"$r")
    d=$(jq -r '.detail' <<<"$r")
    printf '%-60s  %-10s  %s\n' "$p" "$s" "$d"
  done
  printf '\nSummary: clean=%d stale=%d drift=%d missing=%d\n' "$clean" "$stale" "$drift" "$missing"
fi

[ "$((missing + drift + stale))" -eq 0 ] || exit 3

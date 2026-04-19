# k8s-pki rotate-ca — regenerate CAs + every leaf signed by them.
# Destructive: deletes ciphertexts; cluster services will need restart + kubeconfig re-trust.

# shellcheck source=lib.sh
source "$K8S_PKI_LIB"

DRY_RUN=0
CA_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --ca)      CA_NAME="$2"; shift ;;
    -h|--help)
      cat <<EOF
Usage: k8s-pki-rotate-ca [--ca NAME] [--dry-run]

Rotates CAs (default: all three + SA keypair) and every leaf signed by them.
  --ca ca | etcd/ca | front-proxy-ca
  --dry-run
EOF
      exit 0 ;;
    *) die "unknown flag: $1" 2 ;;
  esac
  shift
done

if [ -t 0 ]; then
  printf 'This will regenerate CA keys and every leaf cert signed by them.\n' >&2
  printf 'All cluster services will need to restart; kubeconfigs will need re-trust.\n' >&2
  printf 'Type ROTATE to continue: ' >&2
  read -r resp
  [ "$resp" = "ROTATE" ] || die "aborted" 2
fi

REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) \
  || die "not inside a git repo" 2

ct_path_for() {
  case "$1" in
    common/*)  printf '%s' "$REPO_ROOT/secrets/${1}.age" ;;
    secrets/*) printf '%s' "$REPO_ROOT/${1}.age" ;;
    *) die "unrecognized key: $1" 1 ;;
  esac
}

remove_file() {
  local p="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    [ -f "$p" ] && log info "would delete $p"
    return
  fi
  rm -f "$p"
}

delete_ca_ciphertexts() {
  local ca="$1"
  remove_file "$(ct_path_for "common/k8s-pki/${ca}.crt")"
  remove_file "$(ct_path_for "common/k8s-pki/${ca}.key")"
  log info "deleted CA $ca"
}

delete_leaves_for_ca() {
  local ca="$1"
  # host leaves signed by this CA
  jq -r --arg ca "$ca" '
    .specs.leaves | to_entries |
    map(select(.value.signer == $ca)) |
    .[].key
  ' "$K8S_PKI_DATA" | while IFS= read -r leaf; do
    [ -z "$leaf" ] && continue
    local scope role
    scope=$(jq -r --arg l "$leaf" '.specs.leaves[$l].scope' "$K8S_PKI_DATA")
    jq -r '.hosts | keys[]' "$K8S_PKI_DATA" | while IFS= read -r h; do
      role=$(jq -r --arg h "$h" '.hosts[$h].role' "$K8S_PKI_DATA")
      case "$scope" in
        all) ;;
        master) [ "$role" = master ] || continue ;;
        *) continue ;;
      esac
      remove_file "$(ct_path_for "secrets/${h}/system/homelab-k8s/${leaf}.crt")"
      remove_file "$(ct_path_for "secrets/${h}/system/homelab-k8s/${leaf}.key")"
    done
  done

  # user certs (only when rotating "ca")
  if [ "$ca" = "ca" ]; then
    jq -r '.users | to_entries[] | "\(.value.host)\t\(.value.name)"' "$K8S_PKI_DATA" \
      | while IFS=$'\t' read -r uhost uname; do
          [ -z "$uhost" ] && continue
          for f in cluster-admin.crt cluster-admin.key ca.crt; do
            remove_file "$(ct_path_for "secrets/${uhost}/home/${uname}/homelab-k8s/${f}")"
          done
        done
  fi
}

delete_sa_keypair() {
  remove_file "$(ct_path_for "common/k8s-pki/sa.pub")"
  remove_file "$(ct_path_for "common/k8s-pki/sa.key")"
  log info "deleted SA keypair"
}

if [ -z "$CA_NAME" ]; then
  # Delete all CAs + SA + all their leaves
  for ca in $(jq -r '.specs.cas | keys[]' "$K8S_PKI_DATA"); do
    delete_ca_ciphertexts "$ca"
    delete_leaves_for_ca "$ca"
  done
  delete_sa_keypair
else
  jq -e --arg ca "$CA_NAME" '.specs.cas[$ca]' "$K8S_PKI_DATA" >/dev/null 2>&1 \
    || die "unknown CA: $CA_NAME" 2
  delete_ca_ciphertexts "$CA_NAME"
  delete_leaves_for_ca "$CA_NAME"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log info "dry run complete — no files changed"
  exit 0
fi

# Invoke bootstrap to regenerate everything just deleted
[ -n "${K8S_PKI_BOOTSTRAP:-}" ] || die "K8S_PKI_BOOTSTRAP env var missing (package wrapper should set it)" 1

log info "invoking bootstrap to regenerate deleted material"
bash "$K8S_PKI_BOOTSTRAP" || die "bootstrap failed during rotate-ca" 1

log info "rotate-ca complete — remember: commit secrets submodule, nixos-rebuild switch, kubeconfig re-trust"

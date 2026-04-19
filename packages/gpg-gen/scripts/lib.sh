# shellcheck shell=bash
set -euo pipefail

die() {
  local msg="$1"
  local code="${2:-1}"
  printf 'error: %s\n' "$msg" >&2
  exit "$code"
}

# parse_args "$@" — sets globals MODE, HOST, USER_, OUT_DIR, NAME, EMAIL.
# Exits 2 on usage error. Uses USER_ because USER is a common env var.
parse_args() {
  MODE=""
  HOST=""
  USER_=""
  OUT_DIR=""
  NAME=""
  EMAIL=""
  local want_agenix=0
  local want_out=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --agenix) want_agenix=1; shift ;;
      --out)    want_out=1; OUT_DIR="${2:?--out needs DIR}"; shift 2 ;;
      --host)   HOST="${2:?--host needs HOST}"; shift 2 ;;
      --user)   USER_="${2:?--user needs USER}"; shift 2 ;;
      --name)   NAME="${2:?--name needs NAME}"; shift 2 ;;
      --email)  EMAIL="${2:?--email needs EMAIL}"; shift 2 ;;
      *)        die "unknown flag: $1" 2 ;;
    esac
  done

  if [ "$want_agenix" -eq 1 ] && [ "$want_out" -eq 1 ]; then
    die "only one mode allowed (--agenix or --out)" 2
  fi
  if [ "$want_agenix" -eq 0 ] && [ "$want_out" -eq 0 ]; then
    die "mode required: --agenix or --out" 2
  fi

  if [ "$want_agenix" -eq 1 ]; then
    MODE="agenix"
    [ -n "$HOST" ] || die "--agenix requires --host" 2
    [ -n "$USER_" ] || die "--agenix requires --user" 2
  else
    MODE="out"
  fi
}

# resolve_recipients HOST USER — echo one age pubkey per line; die if none found.
# Honors NIX_BIN for testability (default: "nix").
resolve_recipients() {
  local host="$1"
  local user="$2"
  local nix_bin="${NIX_BIN:-nix}"
  local host_attr=".#nixosConfigurations.${host}.config.capybara.agenix.hostPubkeys"
  local user_attr=".#nixosConfigurations.${host}.config.home-manager.users.${user}.capybara.agenix.userPubkeys"

  local host_json user_json
  host_json="$("$nix_bin" eval --json "$host_attr" 2>/dev/null || echo '[]')"
  user_json="$("$nix_bin" eval --json "$user_attr" 2>/dev/null || echo '[]')"

  local combined
  combined="$(jq -r '.[]' <<<"$host_json"; jq -r '.[]' <<<"$user_json")"
  combined="$(printf '%s\n' "$combined" | sed '/^$/d' | sort -u)"

  if [ -z "$combined" ]; then
    die "no age recipients found for ${user}@${host} (check capybara.agenix.hostPubkeys and userPubkeys)" 1
  fi
  printf '%s\n' "$combined"
}

# age_encrypt_to_recipients OUT RECIPIENTS — encrypt stdin → OUT, -r per recipient.
age_encrypt_to_recipients() {
  local out="$1"
  local recipients="$2"
  local args=()
  while IFS= read -r pk; do
    [ -z "$pk" ] && continue
    args+=(-r "$pk")
  done <<<"$recipients"
  [ "${#args[@]}" -gt 0 ] || die "no recipients" 1
  age -e "${args[@]}" -o "$out"
}

# gen_master_key NAME EMAIL PASSPHRASE — create cert-only NIST P-521 master key,
# no expiry, protected with PASSPHRASE. Echoes the primary fingerprint on stdout.
gen_master_key() {
  local name="$1"
  local email="$2"
  local pw="$3"
  local params
  params=$(mktemp -p "$GNUPGHOME")
  # Shred-then-remove even if gpg below fails.
  trap 'shred -u "$params" 2>/dev/null || rm -f "$params"' RETURN
  cat >"$params" <<EOF
Key-Type: ECDSA
Key-Curve: nistp521
Key-Usage: cert
Name-Real: $name
Name-Email: $email
Expire-Date: 0
Passphrase: $pw
%commit
EOF
  gpg --batch --pinentry-mode loopback --generate-key "$params" >/dev/null 2>&1

  gpg --list-secret-keys --with-colons --with-fingerprint "$email" \
    | awk -F: '$1=="fpr"{print $10; exit}'
}

# add_subkeys FPR PASSPHRASE — add [E], [S], [A] subkeys (nistp521, no expiry).
add_subkeys() {
  local fpr="$1"
  local pw="$2"
  gpg --batch --pinentry-mode loopback --passphrase "$pw" \
    --quick-add-key "$fpr" nistp521 encr never >/dev/null 2>&1
  gpg --batch --pinentry-mode loopback --passphrase "$pw" \
    --quick-add-key "$fpr" nistp521 sign never >/dev/null 2>&1
  gpg --batch --pinentry-mode loopback --passphrase "$pw" \
    --quick-add-key "$fpr" nistp521 auth never >/dev/null 2>&1
}

# export_all FPR OUTDIR PASSPHRASE — write mastersub.key, sub.key, public.asc,
# revoke.asc into OUTDIR.
export_all() {
  local fpr="$1"
  local outdir="$2"
  local pw="$3"
  mkdir -p "$outdir"
  local old_umask
  old_umask=$(umask)
  umask 077
  trap 'umask "$old_umask"' RETURN

  gpg --batch --pinentry-mode loopback --passphrase "$pw" \
    -a --export-secret-keys "$fpr" > "$outdir/mastersub.key"
  gpg --batch --pinentry-mode loopback --passphrase "$pw" \
    -a --export-secret-subkeys "$fpr" > "$outdir/sub.key"
  gpg -a --export "$fpr" > "$outdir/public.asc"

  # Revocation cert — gpg 2.4 rejects --batch here; use --no-tty + --command-fd.
  # Prompt sequence: y (confirm create), 0 (reason: no reason), "" (description), y (confirm).
  printf 'y\n0\n\ny\n' | gpg --no-tty --pinentry-mode loopback --passphrase "$pw" \
    --command-fd 0 --status-fd 2 \
    -a --gen-revoke "$fpr" > "$outdir/revoke.asc" 2>/dev/null
  [ -s "$outdir/revoke.asc" ] || die "revocation cert generation failed (empty revoke.asc)" 1
}

log() {
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*" >&2
}

# prompt_passphrase — read a passphrase twice from /dev/tty, echo to stdout.
# Exits non-zero if the two don't match.
prompt_passphrase() {
  local p1 p2
  printf 'Passphrase: ' >/dev/tty
  read -rs p1 </dev/tty; printf '\n' >/dev/tty
  printf 'Confirm:    ' >/dev/tty
  read -rs p2 </dev/tty; printf '\n' >/dev/tty
  [ "$p1" = "$p2" ] || die "passphrases do not match" 1
  [ -n "$p1" ] || die "empty passphrase" 1
  printf '%s' "$p1"
}

# prompt_if_empty VAR PROMPT — if VAR is empty, read from /dev/tty into VAR.
prompt_if_empty() {
  local var="$1"
  local prompt="$2"
  if [ -z "${!var}" ]; then
    printf '%s: ' "$prompt" >/dev/tty
    read -r "$var" </dev/tty
  fi
}

# ensure_secrets_submodule — die if secrets/ submodule isn't checked out.
ensure_secrets_submodule() {
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || die "not inside a git repo" 1
  [ -d "$repo_root/secrets/.git" ] || [ -f "$repo_root/secrets/.git" ] \
    || die "secrets/ submodule is not initialized; run: git submodule update --init" 1
}

# write_agenix_output EXPORT_DIR HOST USER RECIPIENTS — place encrypted sub.key
# and plain public.asc into the secrets/ submodule.
write_agenix_output() {
  local export_dir="$1"
  local host="$2"
  local user="$3"
  local recipients="$4"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  local target_dir="$repo_root/secrets/$host/home/$user/gpg"
  mkdir -p "$target_dir"

  age_encrypt_to_recipients "$target_dir/sub.key.age" "$recipients" \
    < "$export_dir/sub.key"
  install -m 0644 "$export_dir/public.asc" "$target_dir/public.asc"
  log info "wrote $target_dir/sub.key.age (encrypted)"
  log info "wrote $target_dir/public.asc (plain)"
}

# cold_storage_prompt PATHS... — print a warning listing paths and block until Enter.
cold_storage_prompt() {
  printf '\n' >/dev/tty
  printf '!! COLD STORAGE REQUIRED !!\n' >/dev/tty
  printf 'Move the following files to a secure offline medium NOW:\n' >/dev/tty
  for p in "$@"; do
    printf '  %s\n' "$p" >/dev/tty
  done
  printf '\nPress Enter when moved (files will be shredded on exit): ' >/dev/tty
  read -r _ </dev/tty
}

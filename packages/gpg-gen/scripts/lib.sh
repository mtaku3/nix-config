# shellcheck shell=bash
set -euo pipefail

die() {
  local msg="$1"
  local code="${2:-1}"
  printf 'error: %s\n' "$msg" >&2
  exit "$code"
}

# parse_args "$@" — sets globals DO_AGENIX, DO_OUT, HOST, USER_, OUT_DIR, NAME,
# EMAIL, WANT_PASSPHRASE. Exits 2 on usage error. Both modes may be set
# simultaneously; at least one is required. Uses USER_ because USER is a common
# env var.
parse_args() {
  DO_AGENIX=0
  DO_OUT=0
  HOST=""
  USER_=""
  OUT_DIR=""
  NAME=""
  EMAIL=""
  WANT_PASSPHRASE=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --agenix)     DO_AGENIX=1; shift ;;
      --out)        DO_OUT=1; OUT_DIR="${2:?--out needs DIR}"; shift 2 ;;
      --host)       HOST="${2:?--host needs HOST}"; shift 2 ;;
      --user)       USER_="${2:?--user needs USER}"; shift 2 ;;
      --name)       NAME="${2:?--name needs NAME}"; shift 2 ;;
      --email)      EMAIL="${2:?--email needs EMAIL}"; shift 2 ;;
      --passphrase) WANT_PASSPHRASE=1; shift ;;
      *)            die "unknown flag: $1" 2 ;;
    esac
  done

  if [ "$DO_AGENIX" -eq 0 ] && [ "$DO_OUT" -eq 0 ]; then
    die "mode required: --agenix and/or --out" 2
  fi

  if [ "$DO_AGENIX" -eq 1 ]; then
    [ -n "$HOST" ] || die "--agenix requires --host" 2
    [ -n "$USER_" ] || die "--agenix requires --user" 2
  fi
}

# jq_data [JQ_ARGS...] — run jq -r against $GPG_GEN_DATA with the given args.
# Last arg is the expression, per jq convention.
jq_data() {
  jq -r "$@" "$GPG_GEN_DATA"
}

# resolve_recipients HOST USER — echo one age pubkey per line; die if none found.
# Reads from the flake-derived JSON at $GPG_GEN_DATA (see packages/gpg-gen/data.nix).
resolve_recipients() {
  local host="$1"
  local user="$2"
  [ -n "${GPG_GEN_DATA:-}" ] || die "GPG_GEN_DATA is unset (not running via nix run?)" 1
  [ -r "$GPG_GEN_DATA" ]     || die "GPG_GEN_DATA not readable: $GPG_GEN_DATA" 1

  jq -e --arg h "$host" '.hosts[$h]' "$GPG_GEN_DATA" >/dev/null 2>&1 \
    || die "host '$host' not present in flake (no matching nixosConfiguration for this system)" 1
  jq -e --arg k "${user}@${host}" '.users[$k]' "$GPG_GEN_DATA" >/dev/null 2>&1 \
    || die "user '${user}@${host}' not present in flake" 1

  local combined
  combined="$({
    jq_data --arg h "$host" '.hosts[$h].hostPubkeys[]?'
    jq_data --arg k "${user}@${host}" '.users[$k].userPubkeys[]?'
  } | sed '/^$/d' | sort -u)"

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
# no expiry. If PASSPHRASE is empty, the key is unprotected (%no-protection);
# otherwise it's protected with PASSPHRASE. Echoes the primary fingerprint.
gen_master_key() {
  local name="$1"
  local email="$2"
  local pw="$3"
  local params
  params=$(mktemp -p "$GNUPGHOME")
  # Shred-then-remove even if gpg below fails.
  trap 'shred -u "$params" 2>/dev/null || rm -f "$params"' RETURN
  {
    cat <<EOF
Key-Type: ECDSA
Key-Curve: nistp521
Key-Usage: cert
Name-Real: $name
Name-Email: $email
Expire-Date: 0
EOF
    if [ -n "$pw" ]; then
      printf 'Passphrase: %s\n' "$pw"
    else
      printf '%%no-protection\n'
    fi
    printf '%%commit\n'
  } >"$params"
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
# Exits non-zero if the two don't match or if empty (caller requested one).
prompt_passphrase() {
  local p1 p2
  printf 'Passphrase: ' >/dev/tty
  read -rs p1 </dev/tty; printf '\n' >/dev/tty
  printf 'Confirm:    ' >/dev/tty
  read -rs p2 </dev/tty; printf '\n' >/dev/tty
  [ "$p1" = "$p2" ] || die "passphrases do not match" 1
  [ -n "$p1" ] || die "empty passphrase (omit --passphrase for unprotected key)" 1
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

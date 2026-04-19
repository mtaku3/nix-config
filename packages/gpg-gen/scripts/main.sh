# shellcheck shell=bash
# shellcheck source=/dev/null
source "$GPG_GEN_LIB"

usage() {
  cat <<'EOF'
Usage: gpg-gen [--agenix --host HOST --user USER | --out DIR] [--name NAME] [--email EMAIL]

Modes (exactly one required):
  --agenix --host HOST --user USER   Encrypt sub.key into the secrets/ submodule
                                     at secrets/HOST/home/USER/gpg/sub.key.age
  --out DIR                          Write raw exported files to DIR

Options:
  --name NAME    Real name for the key UID (prompts if omitted)
  --email EMAIL  Email for the key UID (prompts if omitted)
  --help         Show this help
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "")        usage; exit 2 ;;
esac

parse_args "$@"
prompt_if_empty NAME "Real name"
prompt_if_empty EMAIL "Email"

# Isolated GNUPGHOME so the user's real keyring is untouched.
WORKDIR="$(mktemp -d -t gpg-gen-XXXXXX)"
export GNUPGHOME="$WORKDIR/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

cleanup() {
  local rc="$?"
  # shred secret-key exports if still present
  find "$WORKDIR" -name '*.key' -type f -exec shred -u {} + 2>/dev/null || true
  rm -rf "$WORKDIR"
  exit "$rc"
}
trap cleanup EXIT INT TERM

PASSPHRASE="$(prompt_passphrase)"

log info "generating master key (this may take a minute)…"
FPR="$(gen_master_key "$NAME" "$EMAIL" "$PASSPHRASE")"
[ -n "$FPR" ] || die "master key generation failed" 1
log info "master fingerprint: $FPR"

log info "adding E/S/A subkeys…"
add_subkeys "$FPR" "$PASSPHRASE"

EXPORT_DIR="$WORKDIR/out"
export_all "$FPR" "$EXPORT_DIR" "$PASSPHRASE"
# shellcheck disable=SC2012
log info "exported: $(ls "$EXPORT_DIR" | tr '\n' ' ')"

if [ "$MODE" = "out" ]; then
  mkdir -p "$OUT_DIR"
  install -m 0600 "$EXPORT_DIR/mastersub.key" "$OUT_DIR/mastersub.key"
  install -m 0600 "$EXPORT_DIR/sub.key"       "$OUT_DIR/sub.key"
  install -m 0644 "$EXPORT_DIR/public.asc"    "$OUT_DIR/public.asc"
  install -m 0600 "$EXPORT_DIR/revoke.asc"    "$OUT_DIR/revoke.asc"
  log info "wrote all four files to $OUT_DIR"
  log info "KEY ID: $FPR"
  exit 0
fi

ensure_secrets_submodule
RECIPIENTS="$(resolve_recipients "$HOST" "$USER_")"
write_agenix_output "$EXPORT_DIR" "$HOST" "$USER_" "$RECIPIENTS"

log info "KEY ID: $FPR"
log info "NEXT: commit inside secrets/ submodule, then in the parent repo,"
log info "      set signingKey = \"$FPR\" and capybara.app.dev.gpg.{importSubkeys = true; keyId = \"$FPR\";}."

cold_storage_prompt "$EXPORT_DIR/mastersub.key" "$EXPORT_DIR/revoke.asc"

# shellcheck shell=bash
# shellcheck source=/dev/null
source "$GPG_GEN_LIB"

usage() {
  cat <<'EOF'
Usage: gpg-gen [--agenix --host HOST --user USER] [--out DIR]
               [--name NAME] [--email EMAIL] [--passphrase]

Modes (at least one required, both may be combined):
  --agenix --host HOST --user USER   Encrypt sub.key into the secrets/ submodule
                                     at secrets/HOST/home/USER/gpg/sub.key.age
  --out DIR                          Write raw exported files to DIR
                                     (when combined with --agenix, skips the
                                     cold-storage prompt since files are
                                     already in a user-owned location)

Options:
  --name NAME    Real name for the key UID (prompts if omitted)
  --email EMAIL  Email for the key UID (prompts if omitted)
  --passphrase   Prompt for a passphrase; without this flag the key has none
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

if [ "$DO_AGENIX" -eq 1 ]; then
  ensure_secrets_submodule
  # Resolve recipients now so we fail fast if the flake isn't set up.
  RECIPIENTS="$(resolve_recipients "$HOST" "$USER_")"
  export RECIPIENTS
fi

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

if [ "$WANT_PASSPHRASE" -eq 1 ]; then
  PASSPHRASE="$(prompt_passphrase)"
else
  PASSPHRASE=""
  log info "generating unprotected key (no passphrase); pass --passphrase to set one"
fi

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

if [ "$DO_OUT" -eq 1 ]; then
  mkdir -p "$OUT_DIR"
  install -m 0600 "$EXPORT_DIR/mastersub.key" "$OUT_DIR/mastersub.key"
  install -m 0600 "$EXPORT_DIR/sub.key"       "$OUT_DIR/sub.key"
  install -m 0644 "$EXPORT_DIR/public.asc"    "$OUT_DIR/public.asc"
  install -m 0600 "$EXPORT_DIR/revoke.asc"    "$OUT_DIR/revoke.asc"
  log info "wrote all four files to $OUT_DIR"
fi

if [ "$DO_AGENIX" -eq 1 ]; then
  write_agenix_output "$EXPORT_DIR" "$HOST" "$USER_" "$RECIPIENTS"
  log info "NEXT: commit inside secrets/ submodule, then in the parent repo,"
  log info "      set signingKey = \"$FPR\" and capybara.app.dev.gpg.{importSubkeys = true; keyId = \"$FPR\";}."
fi

log info "KEY ID: $FPR"

# If --out was supplied, the sensitive files live in OUT_DIR (user-owned) —
# skip the cold-storage prompt and the shred of tmp copies is handled by the
# cleanup trap. Otherwise (agenix-only), block until the user relocates the
# tempdir copies.
if [ "$DO_AGENIX" -eq 1 ] && [ "$DO_OUT" -eq 0 ]; then
  cold_storage_prompt "$EXPORT_DIR/mastersub.key" "$EXPORT_DIR/revoke.asc"
fi

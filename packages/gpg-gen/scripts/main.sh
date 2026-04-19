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
  -h|--help|"") usage; exit 0 ;;
esac

die "not implemented yet" 1

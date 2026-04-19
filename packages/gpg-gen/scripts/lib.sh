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

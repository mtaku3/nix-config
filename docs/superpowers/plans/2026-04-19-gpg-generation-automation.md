# GPG Generation Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate GPG key generation (master + E/S/A subkeys per the Zenn method), with agenix deploy for NixOS hosts and a raw-dir dump for non-NixOS machines; on the NixOS side, import the subkeys on home-manager activation.

**Architecture:** One `writeShellApplication` CLI at `packages/gpg-gen/` that runs `gpg` in an isolated tempdir, exports four files, then either encrypts `sub.key` with `age` using recipients pulled from the flake or copies everything to a user-chosen directory. Home module `modules/home/app/dev/gpg/default.nix` grows `importSubkeys`/`keyId` options that trigger a `gpg --import` activation script.

**Tech Stack:** Bash (`writeShellApplication`), bats-core (unit tests), `gnupg`, `age`, `nix eval`. Pattern mirrors the existing `packages/k8s-pki/` structure.

**Spec:** `docs/superpowers/specs/2026-04-19-gpg-generation-automation-design.md`

---

## File Structure

**Create:**
- `packages/gpg-gen/default.nix` — Snowfall-autoloaded package that wraps the script into a `writeShellApplication`.
- `packages/gpg-gen/scripts/main.sh` — CLI entrypoint (arg dispatch + orchestration).
- `packages/gpg-gen/scripts/lib.sh` — testable helpers (arg parsing, recipient resolution, age encryption, logging).
- `packages/gpg-gen/scripts/tests/lib.bats` — bats tests for `lib.sh`.

**Modify:**
- `modules/home/app/dev/gpg/default.nix` — add `importSubkeys` + `keyId` options and an activation script.

Kept tight: `main.sh` + `lib.sh` is enough for a single command. Tests cover what can be cheaply unit-tested (arg parsing, recipient eval, age round-trip); GPG key generation itself is verified by the manual E2E task at the end of the plan.

---

## Task 1: Package skeleton + stub script

**Files:**
- Create: `packages/gpg-gen/default.nix`
- Create: `packages/gpg-gen/scripts/main.sh`

- [ ] **Step 1: Write the package file**

Create `packages/gpg-gen/default.nix`:

```nix
{
  pkgs,
  lib,
  ...
}: let
  libSh = ./scripts/lib.sh;
  mainSh = ./scripts/main.sh;
in
  pkgs.writeShellApplication {
    name = "gpg-gen";
    runtimeInputs = with pkgs; [gnupg age nix coreutils gnused gawk jq git];
    text = ''
      export GPG_GEN_LIB=${libSh}
      ${builtins.readFile mainSh}
    '';
    meta = {
      description = "Generate a GPG identity (master + E/S/A subkeys) and deploy via agenix or to a directory";
      platforms = lib.platforms.unix;
      mainProgram = "gpg-gen";
    };
  }
```

- [ ] **Step 2: Write the stub entrypoint**

Create `packages/gpg-gen/scripts/main.sh`:

```bash
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
```

Create an empty `packages/gpg-gen/scripts/lib.sh` for now (next tasks fill it):

```bash
# shellcheck shell=bash
set -euo pipefail

die() {
  local msg="$1"
  local code="${2:-1}"
  printf 'error: %s\n' "$msg" >&2
  exit "$code"
}
```

- [ ] **Step 3: Verify the build**

Run: `nix build .#gpg-gen -L 2>&1 | tail -5`
Expected: builds successfully, no errors.

- [ ] **Step 4: Verify help output**

Run: `./result/bin/gpg-gen --help`
Expected: prints usage and exits 0.

- [ ] **Step 5: Commit**

```bash
git add packages/gpg-gen/
git -c commit.gpgsign=false commit -m "feat(gpg-gen): package skeleton with --help stub"
```

---

## Task 2: `parse_args` helper (TDD)

**Files:**
- Modify: `packages/gpg-gen/scripts/lib.sh`
- Create: `packages/gpg-gen/scripts/tests/lib.bats`

`parse_args` sets outer-scope variables `MODE`, `HOST`, `USER_`, `OUT_DIR`, `NAME`, `EMAIL` from `"$@"`. It validates: exactly one of `--agenix`/`--out`; `--agenix` requires both `--host` and `--user`; unknown flags → error.

- [ ] **Step 1: Write the failing tests**

Create `packages/gpg-gen/scripts/tests/lib.bats`:

```bash
#!/usr/bin/env bats

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  # shellcheck source=/dev/null
  source "$SCRIPTS_DIR/lib.sh"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "parse_args: --agenix with host+user sets MODE=agenix" {
  parse_args --agenix --host helios --user mtaku3
  [ "$MODE" = "agenix" ]
  [ "$HOST" = "helios" ]
  [ "$USER_" = "mtaku3" ]
}

@test "parse_args: --out sets MODE=out and OUT_DIR" {
  parse_args --out /tmp/backup
  [ "$MODE" = "out" ]
  [ "$OUT_DIR" = "/tmp/backup" ]
}

@test "parse_args: --name and --email are captured" {
  parse_args --out /tmp/x --name "Alice" --email "a@example.com"
  [ "$NAME" = "Alice" ]
  [ "$EMAIL" = "a@example.com" ]
}

@test "parse_args: no mode → exit 2" {
  run parse_args --name "Alice"
  [ "$status" -eq 2 ]
  [[ "$output" == *"mode required"* ]]
}

@test "parse_args: both --agenix and --out → exit 2" {
  run parse_args --agenix --host h --user u --out /tmp/x
  [ "$status" -eq 2 ]
  [[ "$output" == *"one mode"* ]]
}

@test "parse_args: --agenix without --host → exit 2" {
  run parse_args --agenix --user mtaku3
  [ "$status" -eq 2 ]
  [[ "$output" == *"--host"* ]]
}

@test "parse_args: --agenix without --user → exit 2" {
  run parse_args --agenix --host helios
  [ "$status" -eq 2 ]
  [[ "$output" == *"--user"* ]]
}

@test "parse_args: unknown flag → exit 2" {
  run parse_args --whatever
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown"* ]]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nix shell nixpkgs#bats-core -c bats packages/gpg-gen/scripts/tests/lib.bats`
Expected: all 8 tests fail with "parse_args: command not found".

- [ ] **Step 3: Implement `parse_args` in `lib.sh`**

Append to `packages/gpg-gen/scripts/lib.sh`:

```bash
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nix shell nixpkgs#bats-core -c bats packages/gpg-gen/scripts/tests/lib.bats`
Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/gpg-gen/scripts/lib.sh packages/gpg-gen/scripts/tests/lib.bats
git -c commit.gpgsign=false commit -m "feat(gpg-gen): parse_args helper with bats tests"
```

---

## Task 3: `resolve_recipients` helper (TDD with `nix eval` stub)

**Files:**
- Modify: `packages/gpg-gen/scripts/lib.sh`
- Modify: `packages/gpg-gen/scripts/tests/lib.bats`

`resolve_recipients HOST USER` runs two `nix eval --json` commands and echoes the union of host + user pubkeys, one per line. Empty total → die. To make it testable, we let callers override `NIX_BIN` (default `nix`).

- [ ] **Step 1: Write the failing tests**

Append to `packages/gpg-gen/scripts/tests/lib.bats`:

```bash
@test "resolve_recipients: merges host+user pubkeys" {
  # Build a stub that returns different JSON per attrpath substring
  local stub="$TMPDIR_TEST/nix"
  cat >"$stub" <<'EOF'
#!/usr/bin/env bash
# Expect: nix eval --json ".#nixosConfigurations.HOST.config.capybara.agenix.hostPubkeys"
#     or: nix eval --json ".#nixosConfigurations.HOST.config.home-manager.users.USER.capybara.agenix.userPubkeys"
for a in "$@"; do
  case "$a" in
    *hostPubkeys*) echo '["age1host"]'; exit 0 ;;
    *userPubkeys*) echo '["age1user"]'; exit 0 ;;
  esac
done
exit 1
EOF
  chmod +x "$stub"
  NIX_BIN="$stub" run resolve_recipients helios mtaku3
  [ "$status" -eq 0 ]
  [[ "$output" == *"age1host"* ]]
  [[ "$output" == *"age1user"* ]]
}

@test "resolve_recipients: empty lists → exit non-zero" {
  local stub="$TMPDIR_TEST/nix"
  cat >"$stub" <<'EOF'
#!/usr/bin/env bash
echo '[]'
EOF
  chmod +x "$stub"
  NIX_BIN="$stub" run resolve_recipients helios mtaku3
  [ "$status" -ne 0 ]
  [[ "$output" == *"no age recipients"* ]]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nix shell nixpkgs#bats-core -c bats packages/gpg-gen/scripts/tests/lib.bats`
Expected: two new tests fail with "resolve_recipients: command not found"; prior 8 pass.

- [ ] **Step 3: Implement `resolve_recipients`**

Append to `packages/gpg-gen/scripts/lib.sh`:

```bash
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nix shell nixpkgs#bats-core -c bats packages/gpg-gen/scripts/tests/lib.bats`
Expected: all 10 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/gpg-gen/scripts/lib.sh packages/gpg-gen/scripts/tests/lib.bats
git -c commit.gpgsign=false commit -m "feat(gpg-gen): resolve_recipients via nix eval"
```

---

## Task 4: `age_encrypt_to_recipients` helper (TDD)

**Files:**
- Modify: `packages/gpg-gen/scripts/lib.sh`
- Modify: `packages/gpg-gen/scripts/tests/lib.bats`

`age_encrypt_to_recipients OUT_PATH RECIPIENTS_NEWLINE_LIST` reads plaintext from stdin, writes ciphertext to `OUT_PATH`, encrypting to every recipient.

- [ ] **Step 1: Write the failing test**

Append to `packages/gpg-gen/scripts/tests/lib.bats`:

```bash
@test "age_encrypt_to_recipients: round-trips via two recipients" {
  local id1="$TMPDIR_TEST/id1" id2="$TMPDIR_TEST/id2"
  nix shell nixpkgs#age -c age-keygen -o "$id1" 2>/dev/null
  nix shell nixpkgs#age -c age-keygen -o "$id2" 2>/dev/null
  local pk1 pk2
  pk1=$(nix shell nixpkgs#age -c age-keygen -y "$id1" 2>/dev/null)
  pk2=$(nix shell nixpkgs#age -c age-keygen -y "$id2" 2>/dev/null)

  local out="$TMPDIR_TEST/ct.age"
  printf 'secret payload' | age_encrypt_to_recipients "$out" "$(printf '%s\n%s\n' "$pk1" "$pk2")"
  [ -s "$out" ]

  # Decrypt with id1
  run bash -c "nix shell nixpkgs#age -c age -d -i '$id1' '$out'"
  [ "$status" -eq 0 ]
  [ "$output" = "secret payload" ]

  # Decrypt with id2
  run bash -c "nix shell nixpkgs#age -c age -d -i '$id2' '$out'"
  [ "$status" -eq 0 ]
  [ "$output" = "secret payload" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nix shell nixpkgs#bats-core -c bats packages/gpg-gen/scripts/tests/lib.bats`
Expected: the new test fails.

- [ ] **Step 3: Implement `age_encrypt_to_recipients`**

Append to `packages/gpg-gen/scripts/lib.sh`:

```bash
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nix shell nixpkgs#bats-core nixpkgs#age -c bats packages/gpg-gen/scripts/tests/lib.bats`
Expected: all 11 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/gpg-gen/scripts/lib.sh packages/gpg-gen/scripts/tests/lib.bats
git -c commit.gpgsign=false commit -m "feat(gpg-gen): age_encrypt_to_recipients helper"
```

---

## Task 5: GPG generation helpers in `lib.sh`

**Files:**
- Modify: `packages/gpg-gen/scripts/lib.sh`

These drive `gpg`. Verification is manual (bats testing against gpg is slow and brittle). Each helper takes `GNUPGHOME` via env (set by caller).

- [ ] **Step 1: Add the generation helpers**

Append to `packages/gpg-gen/scripts/lib.sh`:

```bash
# gen_master_key NAME EMAIL PASSPHRASE — create cert-only NIST P-521 master key,
# no expiry, protected with PASSPHRASE. Echoes the primary fingerprint on stdout.
gen_master_key() {
  local name="$1"
  local email="$2"
  local pw="$3"
  local params
  params=$(mktemp)
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
  rm -f "$params"

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
  umask 077

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
}
```

- [ ] **Step 2: Smoke-test the helpers interactively**

Run:

```bash
TMP="$(mktemp -d)"
mkdir -p "$TMP/gnupg"; chmod 700 "$TMP/gnupg"
export GNUPGHOME="$TMP/gnupg"
source packages/gpg-gen/scripts/lib.sh
FPR=$(gen_master_key "Plan Smoke" "smoke@example.com" "smoketest")
echo "master: $FPR"
add_subkeys "$FPR" "smoketest"
export_all "$FPR" "$TMP/out" "smoketest"
ls "$TMP/out"
gpg --list-secret-keys
rm -rf "$TMP"
unset GNUPGHOME
```

Expected: `mastersub.key sub.key public.asc revoke.asc` all exist; `gpg -K` shows
`sec nistp521/$FPR [C]` + three `ssb nistp521/... [E]/[S]/[A]` lines.

- [ ] **Step 3: Commit**

```bash
git add packages/gpg-gen/scripts/lib.sh
git -c commit.gpgsign=false commit -m "feat(gpg-gen): gpg generation + export helpers"
```

---

## Task 6: `prompt_passphrase` + `--out` mode glue in `main.sh`

**Files:**
- Modify: `packages/gpg-gen/scripts/main.sh`
- Modify: `packages/gpg-gen/scripts/lib.sh`

- [ ] **Step 1: Add `prompt_passphrase` to `lib.sh`**

Append to `packages/gpg-gen/scripts/lib.sh`:

```bash
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
```

- [ ] **Step 2: Replace `main.sh` with the wired-up orchestration**

Replace the contents of `packages/gpg-gen/scripts/main.sh`:

```bash
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

OUTDIR="$WORKDIR/out"
export_all "$FPR" "$OUTDIR" "$PASSPHRASE"
log info "exported: $(ls "$OUTDIR" | tr '\n' ' ')"

if [ "$MODE" = "out" ]; then
  mkdir -p "$OUT_DIR"
  install -m 0600 "$OUTDIR/mastersub.key" "$OUT_DIR/mastersub.key"
  install -m 0600 "$OUTDIR/sub.key"       "$OUT_DIR/sub.key"
  install -m 0644 "$OUTDIR/public.asc"    "$OUT_DIR/public.asc"
  install -m 0600 "$OUTDIR/revoke.asc"    "$OUT_DIR/revoke.asc"
  log info "wrote all four files to $OUT_DIR"
  log info "KEY ID: $FPR"
  exit 0
fi

die "agenix mode not yet implemented" 1
```

Also add `log` to `lib.sh` if not there yet (it isn't):

```bash
log() {
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*" >&2
}
```

- [ ] **Step 3: Rebuild and smoke-test `--out` mode**

```bash
nix build .#gpg-gen -L 2>&1 | tail -3
OUT="$(mktemp -d)"
./result/bin/gpg-gen --out "$OUT" --name "Plan Smoke" --email "smoke@example.com"
# enter passphrase twice
ls -l "$OUT"
# Import sub.key into a scratch keyring and verify structure:
SCRATCH="$(mktemp -d)"
GNUPGHOME="$SCRATCH" gpg --import "$OUT/sub.key"
GNUPGHOME="$SCRATCH" gpg -K
rm -rf "$OUT" "$SCRATCH"
```

Expected: `mastersub.key sub.key public.asc revoke.asc` exist with the right perms;
`gpg -K` after importing `sub.key` shows `sec#` (stub for primary) + three `ssb` lines `[E]/[S]/[A]`.

- [ ] **Step 4: Commit**

```bash
git add packages/gpg-gen/scripts/
git -c commit.gpgsign=false commit -m "feat(gpg-gen): --out mode end-to-end"
```

---

## Task 7: `--agenix` mode

**Files:**
- Modify: `packages/gpg-gen/scripts/main.sh`
- Modify: `packages/gpg-gen/scripts/lib.sh`

- [ ] **Step 1: Add `ensure_secrets_submodule` and `write_agenix_output` to `lib.sh`**

Append to `packages/gpg-gen/scripts/lib.sh`:

```bash
# ensure_secrets_submodule — die if secrets/ submodule isn't checked out.
ensure_secrets_submodule() {
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || die "not inside a git repo" 1
  [ -d "$repo_root/secrets/.git" ] || [ -f "$repo_root/secrets/.git" ] \
    || die "secrets/ submodule is not initialized; run: git submodule update --init" 1
}

# write_agenix_output EXPORT_DIR HOST USER RECIPIENTS — place encrypted sub.key
# and plain public.asc into the secrets/ submodule, and print the cold-storage paths
# for mastersub.key + revoke.asc.
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
```

- [ ] **Step 2: Add `cold_storage_prompt` to `lib.sh`**

Append:

```bash
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
```

- [ ] **Step 3: Replace the agenix-mode stub in `main.sh`**

Replace the line `die "agenix mode not yet implemented" 1` at the end of `main.sh` with:

```bash
ensure_secrets_submodule
RECIPIENTS="$(resolve_recipients "$HOST" "$USER_")"
write_agenix_output "$OUTDIR" "$HOST" "$USER_" "$RECIPIENTS"

log info "KEY ID: $FPR"
log info "NEXT: commit inside secrets/ submodule, then in the parent repo,"
log info "      set signingKey = \"$FPR\" and capybara.app.dev.gpg.{importSubkeys = true; keyId = \"$FPR\";}."

cold_storage_prompt "$OUTDIR/mastersub.key" "$OUTDIR/revoke.asc"
```

- [ ] **Step 4: Rebuild**

Run: `nix build .#gpg-gen -L 2>&1 | tail -3`
Expected: builds successfully.

- [ ] **Step 5: Commit** (E2E test in Task 10)

```bash
git add packages/gpg-gen/scripts/
git -c commit.gpgsign=false commit -m "feat(gpg-gen): --agenix mode (submodule check, age encrypt, cold-storage prompt)"
```

---

## Task 8: Home module `importSubkeys` + `keyId` options

**Files:**
- Modify: `modules/home/app/dev/gpg/default.nix`

- [ ] **Step 1: Read the current module**

Run: `cat modules/home/app/dev/gpg/default.nix`

- [ ] **Step 2: Rewrite the module with the new options**

Replace the entire contents of `modules/home/app/dev/gpg/default.nix` with:

```nix
{
  lib,
  config,
  pkgs,
  host,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.gpg;
  subKeyPath =
    if cfg.importSubkeys
    then config.age.secrets."gpg/sub.key".path or null
    else null;
in {
  options.capybara.app.dev.gpg = {
    enable = mkBoolOpt false "Whether to enable the gpg";
    importSubkeys = mkBoolOpt false "Import GPG subkeys from agenix on activation";
    keyId = mkOpt types.str "" "Long GPG key id / fingerprint to import";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.gpg = enabled;
      services.gpg-agent = {
        enable = true;
        pinentry.package = pkgs.pinentry-curses;
      };
      capybara.impermanence.directories = [".gnupg"];
    }
    (mkIf cfg.importSubkeys {
      assertions = [
        {
          assertion = config.capybara.agenix.enable;
          message = "capybara.app.dev.gpg.importSubkeys requires capybara.agenix.enable = true";
        }
        {
          assertion = cfg.keyId != "";
          message = "capybara.app.dev.gpg.importSubkeys requires keyId to be set";
        }
      ];

      home.activation.importGpgSubkeys = lib.hm.dag.entryAfter ["writeBoundary"] ''
        SUB_KEY_PATH=${subKeyPath}
        KEY_ID=${escapeShellArg cfg.keyId}
        if [ ! -r "$SUB_KEY_PATH" ]; then
          echo "gpg import: $SUB_KEY_PATH not readable yet, skipping" >&2
        elif ${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons "$KEY_ID" 2>/dev/null \
             | grep -q '^sec'; then
          : "already imported"
        else
          echo "gpg import: importing subkeys for $KEY_ID" >&2
          ${pkgs.gnupg}/bin/gpg --import "$SUB_KEY_PATH" || \
            echo "gpg import: failed (will retry next activation)" >&2
          if ${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons "$KEY_ID" 2>/dev/null \
             | grep -q '^sec'; then
            FPR=$(${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons --with-fingerprint \
                  "$KEY_ID" | ${pkgs.gawk}/bin/awk -F: '$1=="fpr"{print $10; exit}')
            printf '%s:6:\n' "$FPR" \
              | ${pkgs.gnupg}/bin/gpg --import-ownertrust 2>/dev/null || true
          fi
        fi
      '';
    })
  ]);
}
```

- [ ] **Step 3: Verify the module evaluates**

Run: `timeout 120 nix eval ".#nixosConfigurations.helios.config.home-manager.users.mtaku3.capybara.app.dev.gpg" --json 2>&1 | tail -5`
Expected: JSON output with `enable`, `importSubkeys`, `keyId`.

- [ ] **Step 4: Commit**

```bash
git add modules/home/app/dev/gpg/default.nix
git -c commit.gpgsign=false commit -m "feat(gpg): importSubkeys + keyId options with activation hook"
```

---

## Task 9: Preflight checks — missing secrets/ dir + bad recipient path

**Files:**
- Modify: `packages/gpg-gen/scripts/main.sh`

Currently `ensure_secrets_submodule` runs *after* key generation. If the submodule isn't initialized, we've already spent a minute generating a key we'll throw away. Move the cheap preconditions before generation.

- [ ] **Step 1: Move preflight ahead of generation**

In `main.sh`, after `parse_args "$@"` and the name/email prompts but **before** `WORKDIR=...`, insert:

```bash
if [ "$MODE" = "agenix" ]; then
  ensure_secrets_submodule
  # Resolve recipients now so we fail fast if the flake isn't set up.
  RECIPIENTS="$(resolve_recipients "$HOST" "$USER_")"
  export RECIPIENTS
fi
```

Then change the agenix-mode block at the bottom of `main.sh` from:

```bash
ensure_secrets_submodule
RECIPIENTS="$(resolve_recipients "$HOST" "$USER_")"
write_agenix_output "$OUTDIR" "$HOST" "$USER_" "$RECIPIENTS"
```

to just:

```bash
write_agenix_output "$OUTDIR" "$HOST" "$USER_" "$RECIPIENTS"
```

- [ ] **Step 2: Verify preflight fires before generation**

```bash
nix build .#gpg-gen -L 2>&1 | tail -3
./result/bin/gpg-gen --agenix --host nonexistent-host --user nobody --name x --email x@x
```

Expected: fails with "no age recipients found for nobody@nonexistent-host" **before** prompting for passphrase.

- [ ] **Step 3: Commit**

```bash
git add packages/gpg-gen/scripts/main.sh
git -c commit.gpgsign=false commit -m "feat(gpg-gen): preflight checks before key generation"
```

---

## Task 10: End-to-end manual smoke test + README

**Files:**
- Create: `packages/gpg-gen/README.md`

- [ ] **Step 1: Run the `--out` smoke test**

```bash
nix build .#gpg-gen -L
OUT="$(mktemp -d)"
./result/bin/gpg-gen --out "$OUT" --name "E2E Smoke" --email "smoke@example.com"
# Enter a scratch passphrase twice.
ls -l "$OUT"
SCRATCH="$(mktemp -d)"
GNUPGHOME="$SCRATCH" gpg --import "$OUT/sub.key"
GNUPGHOME="$SCRATCH" gpg -K --with-colons | awk -F: '$1=="sec"||$1=="ssb"{print $1,$12}'
rm -rf "$OUT" "$SCRATCH"
```

Expected: `sec` with `c` capability (actually appears as `sec#` since master is stubbed in subkey-only import; that's fine) and three `ssb` lines with `e`, `s`, `a` capabilities respectively.

- [ ] **Step 2: Run the `--agenix` smoke test against a scratch target**

Generate into `secrets/helios/home/mtaku3/gpg/` (but do NOT commit the output — this is a smoke test only):

```bash
./result/bin/gpg-gen --agenix --host helios --user mtaku3 --name "E2E Agenix" --email "smoke@example.com"
# Enter passphrase; when prompted for cold storage, check the paths exist then press Enter.
git -C secrets status
```

Expected:
- `secrets/helios/home/mtaku3/gpg/sub.key.age` (binary, age-encrypted) and `public.asc` appear in `git -C secrets status`.
- The cold-storage prompt lists valid paths to `mastersub.key` and `revoke.asc`.

Decrypt `sub.key.age` with the appropriate age identity to confirm it round-trips:

```bash
# Use whichever age identity matches the helios host or mtaku3@helios user recipient
age -d -i <PATH_TO_AGE_IDENTITY> secrets/helios/home/mtaku3/gpg/sub.key.age > /tmp/decrypted-sub.key
head -1 /tmp/decrypted-sub.key  # expect: -----BEGIN PGP PRIVATE KEY BLOCK-----
rm /tmp/decrypted-sub.key
```

Then discard the smoke-test output:

```bash
git -C secrets checkout -- helios/home/mtaku3/gpg/ 2>/dev/null || true
rm -rf secrets/helios/home/mtaku3/gpg
```

Expected: decryption succeeds, the file starts with the PGP armor header.

- [ ] **Step 3: Write a short README**

Create `packages/gpg-gen/README.md`:

```markdown
# gpg-gen

Automates GPG key generation per the Zenn method (NIST P-521, cert-only master,
`[E]/[S]/[A]` subkeys), with two output modes.

## Modes

### `--out DIR` — non-NixOS / manual

Writes `mastersub.key`, `sub.key`, `public.asc`, `revoke.asc` to `DIR`. Nothing
touches the repo. You manage placement/cold-storage yourself.

```
nix run .#gpg-gen -- --out /mnt/usb/gpg-backup --name "Your Name" --email you@example.com
```

### `--agenix --host HOST --user USER` — NixOS via agenix

Encrypts `sub.key` with `age` using the recipients from
`capybara.agenix.hostPubkeys` and `capybara.agenix.userPubkeys` for the target
host/user, places it at `secrets/HOST/home/USER/gpg/sub.key.age` (plus
`public.asc` plain), and prints cold-storage paths for `mastersub.key` and
`revoke.asc`.

```
nix run .#gpg-gen -- --agenix --host helios --user mtaku3 --name mtaku3 --email me@mtaku3.com
```

Afterwards:
1. Move `mastersub.key` and `revoke.asc` off-disk before hitting Enter.
2. `git -C secrets add … && git -C secrets commit …`
3. In the parent repo: set `signingKey` + `capybara.app.dev.gpg.{importSubkeys = true; keyId = "<FPR>";}` on the target host.
4. `git add … && git commit …` (bumps submodule pointer)
5. `nixos-rebuild switch --flake '.?submodules=1#<host>'`

## Running tests

```
nix shell nixpkgs#bats-core nixpkgs#age -c bats packages/gpg-gen/scripts/tests/
```
```

- [ ] **Step 4: Commit**

```bash
git add packages/gpg-gen/README.md
git -c commit.gpgsign=false commit -m "docs(gpg-gen): README with usage examples"
```

---

## Self-Review

- **Spec coverage:**
  - §Components.1 (Generator CLI) → Tasks 1–7, 9
  - §Components.2 (Home module extension) → Task 8
  - §Components.3 (Recipients via `nix eval`) → Task 3
  - §Flow "Bootstrap for new NixOS host" → Tasks 7, 10 (smoke test exercises it end-to-end)
  - §Flow "Non-NixOS generation" → Task 6, 10
  - §Error handling → Task 2 (flag errors), 3 (no recipients), 7 (submodule), 9 (preflight ordering), 8 (activation fallback)
  - §Testing → Tasks 2, 3, 4 (bats), 5, 6, 10 (manual smoke)
- **Placeholder scan:** no TBDs, every step has concrete code/commands. The only deferred item ("rotation") is called out as explicitly out of scope in the spec.
- **Type consistency:** `MODE`, `HOST`, `USER_`, `OUT_DIR`, `NAME`, `EMAIL`, `FPR`, `RECIPIENTS`, `WORKDIR`, `OUTDIR`, `PASSPHRASE` — names used consistently across Tasks 2, 6, 7, 9. `GPG_GEN_LIB` set in `default.nix` (Task 1), consumed in `main.sh` (Tasks 1, 6). `subKeyPath`/`importSubkeys`/`keyId` consistent in Task 8.

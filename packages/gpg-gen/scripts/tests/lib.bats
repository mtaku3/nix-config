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

@test "parse_args: --agenix with host+user sets DO_AGENIX" {
  parse_args --agenix --host helios --user mtaku3
  [ "$DO_AGENIX" = "1" ]
  [ "$DO_OUT" = "0" ]
  [ "$HOST" = "helios" ]
  [ "$USER_" = "mtaku3" ]
}

@test "parse_args: WANT_PASSPHRASE defaults to 0" {
  parse_args --out /tmp/x
  [ "$WANT_PASSPHRASE" = "0" ]
}

@test "parse_args: --passphrase sets WANT_PASSPHRASE=1" {
  parse_args --out /tmp/x --passphrase
  [ "$WANT_PASSPHRASE" = "1" ]
}

@test "parse_args: --out sets DO_OUT and OUT_DIR" {
  parse_args --out /tmp/backup
  [ "$DO_OUT" = "1" ]
  [ "$DO_AGENIX" = "0" ]
  [ "$OUT_DIR" = "/tmp/backup" ]
}

@test "parse_args: --agenix and --out together sets both" {
  parse_args --agenix --host h --user u --out /tmp/x
  [ "$DO_AGENIX" = "1" ]
  [ "$DO_OUT" = "1" ]
  [ "$OUT_DIR" = "/tmp/x" ]
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

@test "resolve_recipients: merges host+user pubkeys from data JSON" {
  export GPG_GEN_DATA="$TMPDIR_TEST/data.json"
  cat >"$GPG_GEN_DATA" <<'EOF'
{
  "hosts": { "helios": { "hostPubkeys": ["age1host"] } },
  "users": { "mtaku3@helios": { "name": "mtaku3", "host": "helios", "userPubkeys": ["age1user"] } }
}
EOF
  run resolve_recipients helios mtaku3
  [ "$status" -eq 0 ]
  [[ "$output" == *"age1host"* ]]
  [[ "$output" == *"age1user"* ]]
}

@test "resolve_recipients: empty lists → exit non-zero" {
  export GPG_GEN_DATA="$TMPDIR_TEST/data.json"
  cat >"$GPG_GEN_DATA" <<'EOF'
{
  "hosts": { "helios": { "hostPubkeys": [] } },
  "users": { "mtaku3@helios": { "name": "mtaku3", "host": "helios", "userPubkeys": [] } }
}
EOF
  run resolve_recipients helios mtaku3
  [ "$status" -ne 0 ]
  [[ "$output" == *"no age recipients"* ]]
}

@test "resolve_recipients: unknown host → exit non-zero" {
  export GPG_GEN_DATA="$TMPDIR_TEST/data.json"
  echo '{"hosts":{},"users":{}}' >"$GPG_GEN_DATA"
  run resolve_recipients nosuch mtaku3
  [ "$status" -ne 0 ]
  [[ "$output" == *"not present in flake"* ]]
}

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

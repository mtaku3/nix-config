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

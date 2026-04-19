#!/usr/bin/env bats

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  source "$SCRIPTS_DIR/lib.sh"

  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "pem_expiry_seconds returns positive seconds for a fresh 30-day cert" {
  local pem="$TMPDIR_TEST/test.pem"
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMPDIR_TEST/key" -out "$pem" \
    -subj "/CN=test" -days 30 2>/dev/null
  run pem_expiry_seconds "$pem"
  [ "$status" -eq 0 ]
  [ "$output" -gt 86400 ]
  [ "$output" -lt 2678400 ]
}

@test "age_recipients_of extracts recipient header lines from ciphertext" {
  local key="$TMPDIR_TEST/id.age"
  age-keygen -o "$key" 2>/dev/null
  local pub
  pub=$(age-keygen -y "$key")
  local ct="$TMPDIR_TEST/ciphertext.age"
  echo "plaintext" | age -r "$pub" -o "$ct"
  run age_recipients_of "$ct"
  [ "$status" -eq 0 ]
  # output should contain at least one non-empty line describing the recipient.
  [ -n "$output" ]
}

@test "recipient_set_eq returns 0 for equal unsorted sets" {
  run recipient_set_eq $'a\nb\nc' $'c\na\nb'
  [ "$status" -eq 0 ]
}

@test "recipient_set_eq returns 1 for differing sets" {
  run recipient_set_eq $'a\nb' $'a\nc'
  [ "$status" -eq 1 ]
}

@test "tmpl_host substitutes host tokens" {
  local host_json='{"name":"m5p01","advertiseIP":"192.168.10.102","masterAddress":"192.168.10.102"}'
  run bash -c 'source '"$SCRIPTS_DIR/lib.sh"'; echo "system:node:{host.name} at {host.advertiseIP}" | tmpl_host '"'$host_json'"
  [ "$status" -eq 0 ]
  [ "$output" = "system:node:m5p01 at 192.168.10.102" ]
}

@test "die writes to stderr and exits" {
  run bash -c 'source '"$SCRIPTS_DIR/lib.sh"'; die "boom" 7'
  [ "$status" -eq 7 ]
  [[ "$output" == *"boom"* ]]
}

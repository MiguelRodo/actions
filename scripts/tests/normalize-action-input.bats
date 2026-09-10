#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/normalize-action-input.sh"

@test "normalizes mixed whitespace and case" {
  run "$SCRIPT" $'  V1.2.3 \n\t'
  [ "$status" -eq 0 ]
  [ "$output" = "v1.2.3" ]
}

@test "leading echo options and shell metacharacters remain literal data" {
  value='-N;$(touch should-not-exist);{"JSON":TRUE};quote'"'"';C:\Path'

  run "$SCRIPT" "$value"
  [ "$status" -eq 0 ]
  [ "$output" = '-n;$(touchshould-not-exist);{"json":true};quote'"'"';c:\path' ]
  [ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]
}

@test "requires exactly one input" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]

  run "$SCRIPT" one two
  [ "$status" -ne 0 ]
}

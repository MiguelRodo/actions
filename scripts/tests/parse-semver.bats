#!/usr/bin/env bats

# Unit tests for scripts/parse-semver.sh

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/parse-semver.sh"

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------

@test "fails with no arguments" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Standard semver tags (vX.Y.Z)
# ---------------------------------------------------------------------------

@test "standard semver returns empty prefix and components" {
  run bash "$SCRIPT" v1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "|1|2|3" ]
}

@test "standard semver with zero major" {
  run bash "$SCRIPT" v0.1.0
  [ "$status" -eq 0 ]
  [ "$output" = "|0|1|0" ]
}

@test "standard semver with large numbers" {
  run bash "$SCRIPT" v10.20.30
  [ "$status" -eq 0 ]
  [ "$output" = "|10|20|30" ]
}

@test "standard semver with pre-release suffix still matches" {
  run bash "$SCRIPT" v2.3.4-beta.1
  [ "$status" -eq 0 ]
  [ "$output" = "|2|3|4" ]
}

# ---------------------------------------------------------------------------
# Branch-prefixed semver tags ({prefix}-vX.Y.Z)
# ---------------------------------------------------------------------------

@test "branch-prefixed semver produces prefix and components" {
  run bash "$SCRIPT" main-v1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "main|1|2|3" ]
}

@test "branch-prefixed semver with multi-segment prefix" {
  run bash "$SCRIPT" feature-foo-v3.0.0
  [ "$status" -eq 0 ]
  [ "$output" = "feature-foo|3|0|0" ]
}

@test "branch-prefixed semver with zero major" {
  run bash "$SCRIPT" dev-v0.5.2
  [ "$status" -eq 0 ]
  [ "$output" = "dev|0|5|2" ]
}

# ---------------------------------------------------------------------------
# Non-semver tags produce empty output
# ---------------------------------------------------------------------------

@test "non-semver tag 'latest' produces empty output" {
  run bash "$SCRIPT" latest
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "partial semver 'v1.2' produces empty output" {
  run bash "$SCRIPT" v1.2
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "plain number tag produces empty output" {
  run bash "$SCRIPT" 123
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

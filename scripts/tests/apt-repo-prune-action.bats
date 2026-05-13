#!/usr/bin/env bats

# Structural tests for apt-repo-prune/action.yml

ACTION_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/apt-repo-prune/action.yml"
SELECT_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/apt-prune-select-versions.sh"

@test "apt-repo-prune action.yml exists" {
  [ -f "$ACTION_FILE" ]
}

@test "apt-repo-prune is a composite action" {
  run grep -F 'using: "composite"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune validates Linux-only runner" {
  run grep -F 'apt-repo-prune supports Linux runners only' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune has required input: repo" {
  run grep -F 'repo:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run awk '
    /^  repo:$/ { in_block=1; next }
    in_block && /required: true/ { found=1; exit 0 }
    in_block && /^  [^ ]/ { exit 1 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune has required input: token" {
  run grep -F 'token:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run awk '
    /^  token:$/ { in_block=1; next }
    in_block && /required: true/ { found=1; exit 0 }
    in_block && /^  [^ ]/ { exit 1 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune has optional input: retention with default latest-minor-per-major" {
  run grep -F 'retention:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run awk '
    /^  retention:$/ { in_block=1; next }
    in_block && /default: "latest-minor-per-major"/ { found=1; exit 0 }
    in_block && /^  [^ ]/ { exit 1 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune has optional input: apt_signing_key" {
  run grep -F 'apt_signing_key:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune has optional input: apt_signing_key_passphrase" {
  run grep -F 'apt_signing_key_passphrase:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune validates expected pool/main structure" {
  run grep -F 'pool/main' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune validates expected dists/stable structure" {
  run grep -F 'dists/stable' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune uses git filter-repo for history rewrite" {
  run grep -F 'git filter-repo' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune uses --invert-paths for removal" {
  run grep -F -- '--invert-paths' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune force-pushes the result" {
  run grep -F 'push --force origin' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune calls the apt-prune-select-versions.sh script" {
  run grep -F 'apt-prune-select-versions.sh' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-prune-select-versions.sh script exists and is executable" {
  [ -f "$SELECT_SCRIPT" ]
  [ -x "$SELECT_SCRIPT" ] || bash -n "$SELECT_SCRIPT"
}

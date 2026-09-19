#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/update-r-description-version.sh"
ACTION_FILE="$ROOT_DIR/r-version-release/action.yml"

@test "r-version-release updates only the DESCRIPTION Version field" {
  description="$BATS_TEST_TMPDIR/DESCRIPTION"
  cat > "$description" <<'EOF'
Package: example
Title: Example package
Version: 1.2.3
Description: Keep Version: text elsewhere untouched.
EOF

  run bash "$SCRIPT" 2.0.1 "$description"
  [ "$status" -eq 0 ]

  run grep -Fx 'Version: 2.0.1' "$description"
  [ "$status" -eq 0 ]
  run grep -Fx 'Package: example' "$description"
  [ "$status" -eq 0 ]
  run grep -Fx 'Description: Keep Version: text elsewhere untouched.' "$description"
  [ "$status" -eq 0 ]
}

@test "r-version-release rejects an invalid version before changing DESCRIPTION" {
  description="$BATS_TEST_TMPDIR/DESCRIPTION"
  printf 'Package: example\nVersion: 1.2.3\n' > "$description"
  before="$(cat "$description")"

  run bash "$SCRIPT" '2.0.1; touch nope' "$description"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid semver"* ]]
  [ "$(cat "$description")" = "$before" ]
  [ ! -e "$BATS_TEST_TMPDIR/nope" ]
}

@test "r-version-release fails when DESCRIPTION has no Version field" {
  description="$BATS_TEST_TMPDIR/DESCRIPTION"
  printf 'Package: example\nTitle: Example\n' > "$description"

  run bash "$SCRIPT" 2.0.1 "$description"
  [ "$status" -ne 0 ]
  [[ "$output" == *"has no Version field"* ]]
}

@test "r-version-release action delegates DESCRIPTION mutation to the tested helper" {
  run grep -F 'bash "$GITHUB_ACTION_PATH/../scripts/update-r-description-version.sh" "$NEW_VERSION" DESCRIPTION' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'sed -i "s/^Version: .*/Version:' "$ACTION_FILE"
  [ "$status" -ne 0 ]
}

#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/update-r-description-version.sh"

@test "r-version-release mutates DESCRIPTION and identifies the release tarball" {
  description="$BATS_TEST_TMPDIR/DESCRIPTION"
  cat > "$description" <<'EOF'
Package: example
Title: Example package
Version: 1.2.3
Description: Keep Version: text elsewhere untouched.
EOF
  touch "$BATS_TEST_TMPDIR/example_1.2.3.tar.gz"

  cd "$BATS_TEST_TMPDIR"
  run bash "$SCRIPT" 2.0.1 "$description"
  [ "$status" -eq 0 ]
  [ "$output" = "example_2.0.1.tar.gz" ]

  run grep -Fx 'Version: 2.0.1' "$description"
  [ "$status" -eq 0 ]
  run grep -Fx 'Description: Keep Version: text elsewhere untouched.' "$description"
  [ "$status" -eq 0 ]
}

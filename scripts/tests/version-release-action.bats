#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/update-package-versions.sh"
ACTION_FILE="$ROOT_DIR/version-release/action.yml"

@test "version-release updates a Python-only repository with the shared bump helper" {
  repo="$BATS_TEST_TMPDIR/python-only"
  mkdir -p "$repo"
  cat > "$repo/pyproject.toml" <<'EOF'
[project]
name = "example"
version = "1.2.3"
EOF

  cd "$repo"
  run bash "$SCRIPT" "" "" "" patch
  [ "$status" -eq 0 ]
  run grep -Fx 'version = "1.2.4"' pyproject.toml
  [ "$status" -eq 0 ]
  [ ! -e DESCRIPTION ]
}

@test "version-release updates an R-only repository with the package override" {
  repo="$BATS_TEST_TMPDIR/r-only"
  mkdir -p "$repo"
  cat > "$repo/DESCRIPTION" <<'EOF'
Package: example
Version: 2.4.8
Title: Example package
EOF

  cd "$repo"
  run bash "$SCRIPT" "" "" " V3.1.0 " patch
  [ "$status" -eq 0 ]
  run grep -Fx 'Version: 3.1.0' DESCRIPTION
  [ "$status" -eq 0 ]
  [ ! -e pyproject.toml ]
}

@test "version-release honours package override precedence in a combined repository" {
  repo="$BATS_TEST_TMPDIR/combined"
  mkdir -p "$repo"
  cat > "$repo/pyproject.toml" <<'EOF'
[project]
name = "example"
version = "1.0.0"
EOF
  cat > "$repo/DESCRIPTION" <<'EOF'
Package: example
Version: 1.0.0
Title: Example package
EOF

  cd "$repo"
  run bash "$SCRIPT" " V4.0.0 " " v4.1.0 " "" minor
  [ "$status" -eq 0 ]
  run grep -Fx 'version = "4.1.0"' pyproject.toml
  [ "$status" -eq 0 ]
  run grep -Fx 'Version: 4.0.0' DESCRIPTION
  [ "$status" -eq 0 ]
}

@test "version-release delegates package edits to the tested helper" {
  run grep -F 'scripts/update-package-versions.sh' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F "tr -d '[:space:]'" "$ACTION_FILE"
  [ "$status" -ne 0 ]
  run grep -F 'py_major + 1' "$ACTION_FILE"
  [ "$status" -ne 0 ]
  run grep -F 'r_major + 1' "$ACTION_FILE"
  [ "$status" -ne 0 ]
}

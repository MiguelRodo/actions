#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
RESOLVE="$ROOT_DIR/scripts/resolve-release-version.sh"
PROGRESSION="$ROOT_DIR/scripts/check-release-progression.sh"

setup() {
  REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO_DIR"
  cd "$REPO_DIR" || return 1
  git init --quiet --initial-branch=main .
  git config user.name "Test User"
  git config user.email "test@example.com"
  echo base > file.txt
  git add file.txt
  git commit --quiet -m base
}

@test "release version resolver normalizes exact version and tag refs" {
  run bash "$RESOLVE" " V1.2.3 " "" "0.0.0" false
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]

  export GITHUB_REF_TYPE=tag
  export GITHUB_REF_NAME="V2.3.4"
  run bash "$RESOLVE" "" "" "0.0.0" true
  [ "$status" -eq 0 ]
  [ "$output" = "2.3.4" ]
}

@test "release version resolver bumps latest semver tag and uses fallback when no tag exists" {
  run bash "$RESOLVE" "" patch "3.4.5" false
  [ "$status" -eq 0 ]
  [ "$output" = "3.4.6" ]

  git tag v5.1.7
  run bash "$RESOLVE" "" minor "3.4.5" false
  [ "$status" -eq 0 ]
  [ "$output" = "5.2.0" ]
}

@test "release version resolver rejects conflicting or invalid input" {
  run bash "$RESOLVE" 1.2.3 patch 0.0.0 false
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot set both"* ]]

  run bash "$RESOLVE" nope "" 0.0.0 false
  [ "$status" -eq 1 ]
  [[ "$output" == *"not valid semver"* ]]
}

@test "release progression guard checks the previous semver tag" {
  git tag v1.2.3
  run bash "$PROGRESSION" 1.2.4 false
  [ "$status" -eq 0 ]
  [[ "$output" == *"Version check passed"* ]]

  run bash "$PROGRESSION" 1.2.5 false
  [ "$status" -eq 1 ]
  [[ "$output" == *"more than one increment ahead"* ]]
}

@test "release progression guard validates and honours version_force" {
  git tag v1.2.3

  run bash "$PROGRESSION" 9.9.9 true
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping version progression check"* ]]

  run bash "$PROGRESSION" 1.2.4 maybe
  [ "$status" -eq 1 ]
  [[ "$output" == *"version_force must be 'true' or 'false'"* ]]
}

@test "all reusable release actions use the shared resolver and progression guard" {
  for action in go-version-release rust-version-release r-version-release version-release; do
    file="$ROOT_DIR/$action/action.yml"
    grep -F 'scripts/resolve-release-version.sh' "$file"
    grep -F 'scripts/check-release-progression.sh' "$file"
  done
}

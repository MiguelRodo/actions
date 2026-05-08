#!/usr/bin/env bats

ACTION_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/go-version-release/action.yml"
ACTION_README="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/go-version-release/README.md"

@test "go-version-release action exists and is a composite action" {
  [ -f "$ACTION_FILE" ]
  run grep -F 'using: "composite"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "go-version-release inputs include github_token and go_version defaults" {
  run grep -F 'github_token:' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'go_version:' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'default: "1.22"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "determine version logic enforces mutual exclusivity and uses apply-version-bump script" {
  run grep -F "cannot set both 'version' and 'bump_type'" "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F '$GITHUB_ACTION_PATH/../scripts/apply-version-bump.sh' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "version progression step uses check-version-progression script" {
  run grep -F "if: inputs.version_check == 'true'" "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F '$GITHUB_ACTION_PATH/../scripts/check-version-progression.sh' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "action sets up Go and runs GoReleaser with release --clean" {
  run grep -F 'uses: actions/setup-go@v5' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'go-version: ${{ inputs.go_version }}' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'uses: goreleaser/goreleaser-action@v5' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'args: release --clean' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "tag handling validates existing tag points to HEAD" {
  run grep -F 'git fetch --no-tags origin "refs/tags/${TAG}:refs/tags/${TAG}"' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'already exists on origin but points to' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "go-version-release has dedicated README with checkout guidance" {
  [ -f "$ACTION_README" ]

  run grep -F 'fetch-depth: 0' "$ACTION_README"
  [ "$status" -eq 0 ]
}

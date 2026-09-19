#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTION_FILE="$ROOT_DIR/go-version-release/action.yml"
PUBLISHER="$ROOT_DIR/scripts/publish-apt-repository.sh"

@test "go-version-release composes shared release plumbing around GoReleaser and apt publishing" {
  grep -Fq 'scripts/resolve-release-version.sh' "$ACTION_FILE"
  grep -Fq 'scripts/check-release-progression.sh' "$ACTION_FILE"
  grep -Fq 'scripts/ensure-release-tag.sh' "$ACTION_FILE"
  grep -Fq 'scripts/update-floating-release-tags.sh' "$ACTION_FILE"

  grep -Fq 'GORELEASER_CURRENT_TAG: ${{ steps.get_version.outputs.tag }}' "$ACTION_FILE"
  grep -Fq 'args: release --clean --skip=announce --config "${{ inputs.goreleaser_config }}"' "$ACTION_FILE"
  grep -Fq 'run: "$GITHUB_ACTION_PATH/../scripts/publish-apt-repository.sh"' "$ACTION_FILE"
  grep -Fq "find dist -type f -name '*.deb'" "$PUBLISHER"

  goreleaser_line="$(grep -n 'name: Run GoReleaser' "$ACTION_FILE" | cut -d: -f1)"
  apt_line="$(grep -n 'name: Publish Debian packages to apt repository' "$ACTION_FILE" | cut -d: -f1)"
  floating_line="$(grep -n 'name: Update floating major, minor and latest tags' "$ACTION_FILE" | cut -d: -f1)"
  [ "$goreleaser_line" -lt "$apt_line" ]
  [ "$apt_line" -lt "$floating_line" ]

  ! grep -Fq 'softprops/action-gh-release' "$ACTION_FILE"
  ! grep -Fq 'Publish Scoop manifest' "$ACTION_FILE"
  ! grep -Fq 'Publish Homebrew formula' "$ACTION_FILE"
}

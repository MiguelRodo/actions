#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTION_FILE="$ROOT_DIR/go-version-release/action.yml"

@test "go-version-release delegates publication to GoReleaser and the shared apt publisher" {
  grep -Fq 'GORELEASER_CURRENT_TAG: ${{ steps.get_version.outputs.tag }}' "$ACTION_FILE"
  grep -Fq 'args: release --clean --skip=announce --config "${{ inputs.goreleaser_config }}"' "$ACTION_FILE"
  grep -Fq "if: inputs.apt_repo != ''" "$ACTION_FILE"
  grep -Fq 'run: "$GITHUB_ACTION_PATH/../scripts/publish-apt-repository.sh"' "$ACTION_FILE"

  goreleaser_line="$(grep -n 'name: Run GoReleaser' "$ACTION_FILE" | cut -d: -f1)"
  apt_line="$(grep -n 'name: Publish Debian packages to apt repository' "$ACTION_FILE" | cut -d: -f1)"
  [ "$goreleaser_line" -lt "$apt_line" ]

  ! grep -Fq 'softprops/action-gh-release' "$ACTION_FILE"
  ! grep -Fq 'Publish Scoop manifest' "$ACTION_FILE"
  ! grep -Fq 'Publish Homebrew formula' "$ACTION_FILE"
}

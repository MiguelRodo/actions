#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
WORKFLOW_DIR="$ROOT_DIR/.github/workflows"
INSTALLER="$ROOT_DIR/scripts/install-actionlint.sh"
DEPENDABOT="$ROOT_DIR/.github/dependabot.yml"

@test "external actions in repository workflows use immutable SHA pins with version comments" {
  found=0

  while IFS= read -r line; do
    action_ref=$(sed -E 's/.*uses:[[:space:]]*([^[:space:]#]+).*/\1/' <<< "$line")

    case "$action_ref" in
      ./*)
        continue
        ;;
    esac

    found=1
    ref="${action_ref##*@}"
    [[ "$ref" =~ ^[0-9a-f]{40}$ ]]
    [[ "$line" =~ \#[[:space:]]v[0-9]+\.[0-9]+\.[0-9]+ ]]
  done < <(grep -RhE '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+' "$WORKFLOW_DIR" --include='*.yml')

  [ "$found" -eq 1 ]
}

@test "CI installs actionlint from a pinned verified release archive" {
  run grep -F 'ACTIONLINT_VERSION="1.7.12"' "$INSTALLER"
  [ "$status" -eq 0 ]
  run grep -E 'EXPECTED_SHA256="[0-9a-f]{64}"' "$INSTALLER"
  [ "$status" -eq 0 ]
  run grep -F 'releases/download/v${ACTIONLINT_VERSION}/${ARCHIVE}' "$INSTALLER"
  [ "$status" -eq 0 ]
  run grep -F 'sha256sum --check --status' "$INSTALLER"
  [ "$status" -eq 0 ]
}

@test "workflows do not execute the upstream actionlint main-branch installer" {
  run grep -R -F 'raw.githubusercontent.com/rhysd/actionlint/main' "$WORKFLOW_DIR"
  [ "$status" -ne 0 ]

  run grep -F './scripts/install-actionlint.sh "$RUNNER_TEMP/actionlint"' "$WORKFLOW_DIR/ci.yml"
  [ "$status" -eq 0 ]
  run grep -F './scripts/install-actionlint.sh "$RUNNER_TEMP/actionlint"' "$WORKFLOW_DIR/copilot-setup-steps.yml"
  [ "$status" -eq 0 ]
}

@test "Dependabot maintains GitHub Actions pins monthly in one low-noise group" {
  run grep -F 'package-ecosystem: "github-actions"' "$DEPENDABOT"
  [ "$status" -eq 0 ]
  run grep -F 'interval: "monthly"' "$DEPENDABOT"
  [ "$status" -eq 0 ]
  run grep -F 'open-pull-requests-limit: 1' "$DEPENDABOT"
  [ "$status" -eq 0 ]
  run grep -F 'routine-github-actions:' "$DEPENDABOT"
  [ "$status" -eq 0 ]
  run grep -F -- '- "*"' "$DEPENDABOT"
  [ "$status" -eq 0 ]
}

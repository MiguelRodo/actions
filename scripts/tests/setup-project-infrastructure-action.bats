#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTION_FILE="$ROOT_DIR/setup-project-infrastructure/action.yml"
FILES_SCRIPT="$ROOT_DIR/scripts/setup-project-files.sh"

@test "setup-project-infrastructure remains a composite action with its public inputs" {
  run grep -F 'using: "composite"' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  for input in working_repo template_repo builder_repo config_repo renv_pkgs renv_repos repos_list gh_token; do
    run grep -F "  ${input}:" "$ACTION_FILE"
    [ "$status" -eq 0 ]
  done
}

@test "action delegates parsing and generated files to the behavioural helper" {
  run grep -F 'scripts/setup-project-files.sh' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "repository references preserve valid adversarial branch characters as data" {
  branch='feature/quote'"'"'$(echo-safe)-{json-true}'

  run "$FILES_SCRIPT" parse-repo-ref "octo/repo@$branch"
  [ "$status" -eq 0 ]
  run jq -e --arg branch "$branch" \
    '.repo == "octo/repo" and .branch == $branch' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "repository references reject malformed repositories and control characters" {
  run "$FILES_SCRIPT" parse-repo-ref "missing-owner"
  [ "$status" -ne 0 ]
  [[ "$output" == *"owner/repo"* ]]

  run "$FILES_SCRIPT" parse-repo-ref $'octo/repo@feature\ninjected'
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid branch name"* ]]
}

@test "renv cache generation safely preserves hostile package and repository strings" {
  devcontainer="$BATS_TEST_TMPDIR/devcontainer.json"
  cat > "$devcontainer" <<'JSON'
{
  // Existing comments are accepted.
  "features": {
    "other": {"value": 42}
  }
}
JSON

  packages='quoted "pkg"; apostrophe'"'"'s; C:\packages; $(touch should-not-exist); {"json":true}'
  repositories='https://example.test/a; path with spaces'
  run "$FILES_SCRIPT" update-renv-cache "$devcontainer" "$packages" "$repositories"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]

  run jq -e '
    .features.other.value == 42 and
    .features["ghcr.io/miguelrodo/devcontainers/renv-cache:latest"].pkg == [
      "quoted \"pkg\"",
      "apostrophe'\''s",
      "C:\\packages",
      "$(touch should-not-exist)",
      "{\"json\":true}"
    ] and
    .features["ghcr.io/miguelrodo/devcontainers/renv-cache:latest"].repos == [
      "https://example.test/a",
      "path with spaces"
    ]
  ' "$devcontainer"
  [ "$status" -eq 0 ]
}

@test "builder workflow and config devcontainer are generated as expected" {
  workflow="$BATS_TEST_TMPDIR/generated/.github/workflows/devcontainer-build.yml"
  expected_workflow="$BATS_TEST_TMPDIR/expected-devcontainer-build.yml"
  config="$BATS_TEST_TMPDIR/config path/.devcontainer/devcontainer.json"
  image='ghcr.io/octo/image-quote'"'"'-{"json":true}:latest'

  cat > "$expected_workflow" <<'YAML'
name: Pre-build Dev Container
on:
  push:
    branches:
      - "**"
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
    steps:
      - uses: actions/checkout@v6
      - uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
YAML

  run "$FILES_SCRIPT" write-builder-workflow "$workflow"
  [ "$status" -eq 0 ]
  run diff -u "$expected_workflow" "$workflow"
  [ "$status" -eq 0 ]

  run "$FILES_SCRIPT" write-config-devcontainer "$config" "$image"
  [ "$status" -eq 0 ]
  run jq -e --arg image "$image" '.image == $image' "$config"
  [ "$status" -eq 0 ]
}

@test "repos.list writes shell metacharacters literally and rejects embedded newlines" {
  repos_file="$BATS_TEST_TMPDIR/repos.list"
  repos='octo/one@main; $(touch should-not-exist); {"json":true}; C:\repo'

  run "$FILES_SCRIPT" append-repos-list "$repos_file" "$repos"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]
  run grep -Fx '$(touch should-not-exist)' "$repos_file"
  [ "$status" -eq 0 ]
  run grep -Fx '{"json":true}' "$repos_file"
  [ "$status" -eq 0 ]
  run grep -Fx 'C:\repo' "$repos_file"
  [ "$status" -eq 0 ]

  run "$FILES_SCRIPT" append-repos-list "$repos_file" $'octo/two@main\ninjected'
  [ "$status" -ne 0 ]
  [[ "$output" == *"control characters"* ]]
}

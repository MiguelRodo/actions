#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTION_FILE="$ROOT_DIR/setup-project-infrastructure/action.yml"
ORCHESTRATOR="$ROOT_DIR/scripts/setup-project-infrastructure.sh"
FILES_SCRIPT="$ROOT_DIR/scripts/setup-project-files.sh"

make_command_stubs() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'git cwd=%s args=%s\n' "$PWD" "$*" >> "$CALL_LOG"
case "${1:-}" in
  check-ref-format) exec /usr/bin/git "$@" ;;
  diff) exit 0 ;;
  *) exit 0 ;;
esac
STUB

  cat > "$bin_dir/repos" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'repos cwd=%s args=%s\n' "$PWD" "$*" >> "$CALL_LOG"
[[ "${FAIL_REPOS_COMMAND:-}" != "${1:-}" ]] || exit 23
if [[ "${1:-}" == "clone" ]]; then
  while read -r ref target rest; do
    [[ -n "${ref:-}" ]] || continue
    mkdir -p "../$target"
  done < repos.list
elif [[ "${1:-}" == "workspace" ]]; then
  printf '{}\n' > entire-project.code-workspace
fi
STUB

  cat > "$bin_dir/setupmjr" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'setupmjr cwd=%s args=%s\n' "$PWD" "$*" >> "$CALL_LOG"
[[ "${FAIL_SETUPMJR_COMMAND:-}" != "$*" ]] || exit 24
if [[ "$*" == "repo devcontainer --repo "* ]]; then
  mkdir -p .devcontainer
  printf '{"features":{}}\n' > .devcontainer/devcontainer.json
  printf 'copied\n' > .devcontainer/.hidden-template-file
elif [[ "$*" == "repo action prebuild-devcontainer" ]]; then
  mkdir -p .github/workflows
  printf 'name: prebuild\n' > .github/workflows/prebuild-devcontainer.yml
elif [[ "$*" == "repo readme" ]]; then
  printf '# generated\n' > README.md
fi
STUB

  chmod +x "$bin_dir/git" "$bin_dir/repos" "$bin_dir/setupmjr"
}

run_orchestrator() {
  local workspace="$1"
  shift
  env \
    CALL_LOG="$BATS_TEST_TMPDIR/calls.log" \
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" \
    RUNNER_TEMP="$BATS_TEST_TMPDIR" \
    SETUP_PROJECT_WORKSPACE_ROOT="$workspace" \
    GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md" \
    WORKING_REPO_INPUT='octo/work@main' \
    TEMPLATE_REPO_INPUT='octo/template@main' \
    BUILDER_REPO_INPUT='octo/builder@build' \
    CONFIG_REPO_INPUT='octo/config@cfg' \
    RENV_PKGS_INPUT='pkgA;pkgB' \
    RENV_REPOS_INPUT='octo/lock@main' \
    REPOS_LIST_INPUT='octo/one@main;octo/two@dev' \
    GH_TOKEN='test-token' \
    "$@" \
    "$ORCHESTRATOR"
}

@test "setup-project-infrastructure remains a composite action with its public inputs" {
  run grep -F 'using: "composite"' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  for input in working_repo template_repo builder_repo config_repo renv_pkgs renv_repos repos_list gh_token; do
    run grep -F "  ${input}:" "$ACTION_FILE"
    [ "$status" -eq 0 ]
  done
}

@test "composite action is wiring while orchestration lives in one script" {
  run grep -F 'scripts/setup-project-infrastructure.sh' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'sudo apt-get install -y setupmjr repos jq' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'git clone' "$ACTION_FILE"
  [ "$status" -ne 0 ]
  run grep -F 'repos workspace' "$ACTION_FILE"
  [ "$status" -ne 0 ]
  run grep -F 'setupmjr repo install repos' "$ACTION_FILE"
  [ "$status" -ne 0 ]
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

@test "config devcontainer is generated as expected" {
  config="$BATS_TEST_TMPDIR/config path/.devcontainer/devcontainer.json"
  image='ghcr.io/octo/image-quote'"'"'-{"json":true}:latest'

  run "$FILES_SCRIPT" write-config-devcontainer "$config" "$image"
  [ "$status" -eq 0 ]
  run jq -e --arg image "$image" '.image == $image' "$config"
  [ "$status" -eq 0 ]
}

@test "repos.list writes literal entries once and rejects embedded newlines" {
  repos_file="$BATS_TEST_TMPDIR/repos.list"
  repos='octo/one@main; octo/one@main; $(touch should-not-exist); {"json":true}; C:\repo'

  run "$FILES_SCRIPT" append-repos-list "$repos_file" "$repos"
  [ "$status" -eq 0 ]
  run "$FILES_SCRIPT" append-repos-list "$repos_file" "$repos"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]

  for entry in 'octo/one@main' '$(touch should-not-exist)' '{"json":true}' 'C:\repo'; do
    run grep -Fxc -- "$entry" "$repos_file"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
  done

  run "$FILES_SCRIPT" append-repos-list "$repos_file" $'octo/two@main\ninjected'
  [ "$status" -ne 0 ]
  [[ "$output" == *"control characters"* ]]
}

@test "orchestrator delegates cloning devcontainer and workspace operations" {
  make_command_stubs "$BATS_TEST_TMPDIR/bin"
  : > "$BATS_TEST_TMPDIR/calls.log"

  run run_orchestrator "$BATS_TEST_TMPDIR/workspace"
  [ "$status" -eq 0 ]

  run grep -F 'repos cwd='"$BATS_TEST_TMPDIR"'/workspace/control args=clone --create --fetch-single' "$BATS_TEST_TMPDIR/calls.log"
  [ "$status" -eq 0 ]
  run grep -F 'setupmjr cwd='"$BATS_TEST_TMPDIR"'/workspace/builder_repo_dir args=repo devcontainer --repo octo/template@main' "$BATS_TEST_TMPDIR/calls.log"
  [ "$status" -eq 0 ]
  run grep -F 'setupmjr cwd='"$BATS_TEST_TMPDIR"'/workspace/builder_repo_dir args=repo action prebuild-devcontainer' "$BATS_TEST_TMPDIR/calls.log"
  [ "$status" -eq 0 ]
  run grep -F 'repos cwd='"$BATS_TEST_TMPDIR"'/workspace/working_repo_dir args=create' "$BATS_TEST_TMPDIR/calls.log"
  [ "$status" -eq 0 ]
  run grep -F 'repos cwd='"$BATS_TEST_TMPDIR"'/workspace/working_repo_dir args=codespace' "$BATS_TEST_TMPDIR/calls.log"
  [ "$status" -eq 0 ]
  run grep -F 'repos cwd='"$BATS_TEST_TMPDIR"'/workspace/working_repo_dir args=workspace' "$BATS_TEST_TMPDIR/calls.log"
  [ "$status" -eq 0 ]

  [ -f "$BATS_TEST_TMPDIR/workspace/builder_repo_dir/.devcontainer/.hidden-template-file" ]
  run jq -e '.image == "ghcr.io/octo/builder-build:latest"' \
    "$BATS_TEST_TMPDIR/workspace/config_repo_dir/.devcontainer/devcontainer.json"
  [ "$status" -eq 0 ]
}

@test "orchestrator fails closed when delegated required operations fail" {
  make_command_stubs "$BATS_TEST_TMPDIR/bin"
  : > "$BATS_TEST_TMPDIR/calls.log"

  run run_orchestrator "$BATS_TEST_TMPDIR/workspace-repos-fail" FAIL_REPOS_COMMAND=workspace
  [ "$status" -eq 23 ]

  run run_orchestrator "$BATS_TEST_TMPDIR/workspace-readme-fail" FAIL_SETUPMJR_COMMAND='repo readme'
  [ "$status" -eq 24 ]
}

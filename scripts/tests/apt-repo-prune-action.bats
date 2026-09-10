#!/usr/bin/env bats

ACTION_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/apt-repo-prune/action.yml"
SELECT_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/apt-prune-select-versions.sh"
PLAN_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/apt-prune-plan.sh"

setup() {
  TEST_ROOT="$(mktemp -d)"
  MOCK_BIN="$TEST_ROOT/bin"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/dpkg-deb" <<'EOF'
#!/usr/bin/env bash
base="$(basename "$2" .deb)"
IFS=_ read -r name version arch <<<"$base"
case "$3" in
  Package) printf '%s\n' "$name" ;;
  Version) printf '%s\n' "$version" ;;
  Architecture) printf '%s\n' "$arch" ;;
esac
EOF
  chmod +x "$MOCK_BIN/dpkg-deb"
  export PATH="$MOCK_BIN:$PATH"
  export GITHUB_OUTPUT="$TEST_ROOT/output"
  export RUNNER_TEMP="$TEST_ROOT"
  : > "$GITHUB_OUTPUT"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

make_deb() {
  local repo_dir="$1"
  local version="$2"
  mkdir -p "$repo_dir/pool/main/d/demo"
  touch "$repo_dir/pool/main/d/demo/demo_${version}_amd64.deb"
}

@test "apt-repo-prune action.yml exists" {
  [ -f "$ACTION_FILE" ]
}

@test "apt-repo-prune is a composite action" {
  run grep -F 'using: "composite"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune validates Linux-only runner" {
  run grep -F 'apt-repo-prune supports Linux runners only' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune does NOT have repo input" {
  run grep -F 'repo:' "$ACTION_FILE"
  [ "$status" -ne 0 ]
}

@test "apt-repo-prune has required input: token" {
  run grep -F 'token:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run awk '
    /^  token:$/ { in_block=1; next }
    in_block && /required: true/ { found=1; exit 0 }
    in_block && /^  [^ ]/ { exit 1 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune has optional input: retention with default latest-per-major" {
  run grep -F 'retention:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run awk '
    /^  retention:$/ { in_block=1; next }
    in_block && /default: "latest-per-major"/ { found=1; exit 0 }
    in_block && /^  [^ ]/ { exit 1 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune has optional input: apt_signing_key" {
  run grep -F 'apt_signing_key:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune has optional input: apt_signing_key_passphrase" {
  run grep -F 'apt_signing_key_passphrase:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune uses git filter-repo for history rewrite" {
  run grep -F 'git filter-repo' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune uses --invert-paths for removal" {
  run grep -F -- '--invert-paths' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune force-pushes the result" {
  run grep -F 'push --force origin' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune delegates plan decisions to the behavioural helper" {
  run grep -F 'apt-prune-plan.sh' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-prune-select-versions.sh script exists" {
  [ -f "$SELECT_SCRIPT" ]
}

@test "apt-prune-select-versions.sh has valid bash syntax" {
  bash -n "$SELECT_SCRIPT"
}

@test "plan treats an empty repository as a successful no-op and cleans the clone" {
  repo_dir="$TEST_ROOT/empty repo"
  mkdir -p "$repo_dir"

  run "$PLAN_SCRIPT" latest "$repo_dir" "octo/apt repo" main
  [ "$status" -eq 0 ]
  [[ "$output" == *"repository has no packages"* ]]
  [ "$(cat "$GITHUB_OUTPUT")" = "should_prune=false" ]
  [ ! -d "$repo_dir" ]
}

@test "plan rejects package pools without dists metadata and cleans the clone" {
  repo_dir="$TEST_ROOT/missing metadata"
  make_deb "$repo_dir" 1.0.0

  run "$PLAN_SCRIPT" latest "$repo_dir" "octo/apt repo" main
  [ "$status" -ne 0 ]
  [[ "$output" == *"expected dists/stable"* ]]
  [ ! -d "$repo_dir" ]
}

@test "plan reports no pruning when retention is already satisfied" {
  repo_dir="$TEST_ROOT/current"
  make_deb "$repo_dir" 1.0.0
  mkdir -p "$repo_dir/dists/stable"

  run "$PLAN_SCRIPT" latest "$repo_dir" "octo/apt" main
  [ "$status" -eq 0 ]
  [ "$(cat "$GITHUB_OUTPUT")" = "should_prune=false" ]
  [ ! -d "$repo_dir" ]
}

@test "plan returns retained clone and exact removal file when pruning is required" {
  repo_dir="$TEST_ROOT/prune"
  make_deb "$repo_dir" 1.0.0
  make_deb "$repo_dir" 2.0.0
  mkdir -p "$repo_dir/dists/stable"

  run "$PLAN_SCRIPT" latest "$repo_dir" "octo/apt" release
  [ "$status" -eq 0 ]
  grep -Fxq "should_prune=true" "$GITHUB_OUTPUT"
  grep -Fxq "apt_repo_dir=$repo_dir" "$GITHUB_OUTPUT"
  grep -Fxq "default_branch=release" "$GITHUB_OUTPUT"
  paths_file="$(sed -n 's/^paths_to_remove_file=//p' "$GITHUB_OUTPUT")"
  [ -f "$paths_file" ]
  [ "$(cat "$paths_file")" = "pool/main/d/demo/demo_1.0.0_amd64.deb" ]
  [ -d "$repo_dir" ]
}

@test "apt-repo-prune uses temporary askpass authentication with token-free remotes" {
  run grep -F 'scripts/git-auth-askpass.sh' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'setup_git_askpass' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'cleanup_git_askpass' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run awk '
    /Configure Secure Git Authentication/ { in_auth=1 }
    in_auth && /trap cleanup_git_askpass EXIT/ { trap_seen=1 }
    in_auth && /setup_git_askpass/ { valid=trap_seen; exit }
    END { exit valid ? 0 : 1 }
  ' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'git config --global url.' "$ACTION_FILE"
  [ "$status" -ne 0 ]
  run grep -E 'git remote (add|set-url).*x-access-token' "$ACTION_FILE"
  [ "$status" -ne 0 ]
}

@test "apt-repo-prune uses github.repository context instead of repo input" {
  run grep -F 'GITHUB_REPOSITORY' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune uses default_branch context for branch, not hardcoded main" {
  run grep -F 'github.event.repository.default_branch' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'GITHUB_REF_NAME' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F -- '--branch main' "$ACTION_FILE"
  [ "$status" -ne 0 ]
}

@test "apt-repo-prune creates passphrase file only when passphrase is non-empty" {
  run awk '
    /if \[ -n "\$APT_SIGNING_KEY_PASSPHRASE" \]/ { in_block=1; next }
    in_block && /^[[:space:]]*fi([[:space:]]|;|$)/ { in_block=0; next }
    in_block && /gpg-passphrase/ { found=1; exit 0 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune uses passphrase-file option only when GPG_PASSPHRASE_FILE is set" {
  run awk '
    /if \[ -n "\$GPG_PASSPHRASE_FILE" \]/ { in_block=1; next }
    in_block && /^[[:space:]]*fi([[:space:]]|;|$)/ { in_block=0; next }
    in_block && /--passphrase-file/ { found=1; exit 0 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune cleans up passphrase file only when it was created" {
  run grep -E '\[ -n "\$GPG_PASSPHRASE_FILE" \][[:space:]]+&&[[:space:]]+rm -f' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune plan step has id: plan" {
  run awk '
    /^    - name: Analyze prune plan$/ { in_step=1; next }
    in_step && /^      id: plan$/ { found=1; exit 0 }
    in_step && /^    - name:/ { in_step=0 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune no-op step is conditional on should_prune != true" {
  run grep -F "steps.plan.outputs.should_prune != 'true'" "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune execute step is conditional on should_prune == true" {
  run grep -F "steps.plan.outputs.should_prune == 'true'" "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune execute step reads apt_repo_dir from plan outputs" {
  run grep -F 'steps.plan.outputs.apt_repo_dir' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "apt-repo-prune execute step reads paths_to_remove_file from plan outputs" {
  run grep -F 'steps.plan.outputs.paths_to_remove_file' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

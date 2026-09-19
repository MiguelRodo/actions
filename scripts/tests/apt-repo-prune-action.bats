#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTION_FILE="$ROOT_DIR/apt-repo-prune/action.yml"
PRUNE_SCRIPT="$ROOT_DIR/scripts/apt-repo-prune.sh"
SELECT_SCRIPT="$ROOT_DIR/scripts/apt-prune-select-versions.sh"
PLAN_SCRIPT="$ROOT_DIR/scripts/apt-prune-plan.sh"

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

  cat > "$MOCK_BIN/dpkg-scanpackages" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "$MOCK_BIN/apt-ftparchive" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  chmod +x "$MOCK_BIN"/*
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

@test "apt-repo-prune is a Linux-only composite action with the documented inputs" {
  [ -f "$ACTION_FILE" ]
  grep -Fq 'using: "composite"' "$ACTION_FILE"
  grep -Fq 'apt-repo-prune supports Linux runners only' "$ACTION_FILE"
  ! grep -Fq 'repo:' "$ACTION_FILE"

  awk '
    /^  token:$/ { in_block=1; next }
    in_block && /required: true/ { found=1; exit 0 }
    in_block && /^  [^ ]/ { exit 1 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"

  awk '
    /^  retention:$/ { in_block=1; next }
    in_block && /default: "latest-per-major"/ { found=1; exit 0 }
    in_block && /^  [^ ]/ { exit 1 }
    END { exit found ? 0 : 1 }
  ' "$ACTION_FILE"

  grep -Fq 'apt_signing_key:' "$ACTION_FILE"
  grep -Fq 'apt_signing_key_passphrase:' "$ACTION_FILE"
}

@test "action delegates privileged prune orchestration to the script" {
  # shellcheck disable=SC2016
  grep -Fq 'run: bash "$GITHUB_ACTION_PATH/../scripts/apt-repo-prune.sh"' "$ACTION_FILE"
  ! grep -Fq 'git filter-repo' "$ACTION_FILE"
  ! grep -Fq 'push --force' "$ACTION_FILE"
  ! grep -Fq 'dpkg-scanpackages --multiversion' "$ACTION_FILE"
}

@test "prune script keeps history rewrite and force-push safeguards" {
  bash -n "$PRUNE_SCRIPT"
  grep -Fq 'git filter-repo' "$PRUNE_SCRIPT"
  grep -Fq -- '--invert-paths' "$PRUNE_SCRIPT"
  grep -Fq -- '--paths-from-file "$PATHS_TO_REMOVE_FILE"' "$PRUNE_SCRIPT"
  grep -Fq 'git rev-list --max-parents=0 HEAD' "$PRUNE_SCRIPT"
  grep -Fq 'git push --force origin "HEAD:${DEFAULT_BRANCH}"' "$PRUNE_SCRIPT"
}

@test "prune script uses shared authentication and metadata helpers" {
  grep -Fq 'source "$SCRIPT_DIR/git-auth-askpass.sh"' "$PRUNE_SCRIPT"
  grep -Fq 'source "$SCRIPT_DIR/apt-repository-metadata.sh"' "$PRUNE_SCRIPT"
  grep -Fq 'setup_git_askpass' "$PRUNE_SCRIPT"
  grep -Fq 'cleanup_git_askpass' "$PRUNE_SCRIPT"
  grep -Fq 'apt_repository_setup_signing' "$PRUNE_SCRIPT"
  grep -Fq 'apt_repository_cleanup_signing' "$PRUNE_SCRIPT"
  grep -Fq 'apt_repository_regenerate_metadata' "$PRUNE_SCRIPT"
  ! grep -Fq 'git config --global url.' "$PRUNE_SCRIPT"
  ! grep -E -q 'git remote (add|set-url).*x-access-token' "$PRUNE_SCRIPT"
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

@test "orchestrator no-op clones securely, avoids a push, and cleans authentication" {
  git_log="$TEST_ROOT/git.log"
  askpass_path_file="$TEST_ROOT/askpass-path"
  export FAKE_GIT_LOG="$git_log"
  export FAKE_ASKPASS_PATH_FILE="$askpass_path_file"

  cat > "$MOCK_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GIT_LOG"
case "$1" in
  clone)
    [ -x "$GIT_ASKPASS" ]
    [ "$($GIT_ASKPASS 'Username for https://github.com')" = "x-access-token" ]
    [ "$($GIT_ASKPASS 'Password for https://github.com')" = "prune-token" ]
    printf '%s\n' "$GIT_ASKPASS" > "$FAKE_ASKPASS_PATH_FILE"
    destination="${*: -1}"
    mkdir -p "$destination/.git" "$destination/pool/main/d/demo" "$destination/dists/stable"
    touch "$destination/pool/main/d/demo/demo_1.0.0_amd64.deb"
    ;;
  *)
    echo "Unexpected git invocation: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$MOCK_BIN/git"

  run env \
    PATH="$MOCK_BIN:$PATH" \
    RETENTION_RAW="LATEST" \
    DEFAULT_BRANCH_INPUT="release" \
    APT_SIGNING_KEY="" \
    APT_SIGNING_KEY_PASSPHRASE="" \
    PUSH_TOKEN="prune-token" \
    GITHUB_REPOSITORY="owner/packages" \
    GITHUB_SERVER_URL="https://github.com" \
    GITHUB_REF_NAME="ignored" \
    RUNNER_TEMP="$TEST_ROOT" \
    bash "$PRUNE_SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No history rewrite or push required."* ]]
  grep -q '^clone --branch release --single-branch https://github.com/owner/packages.git ' "$git_log"
  ! grep -q '^push ' "$git_log"
  [ ! -e "$(dirname "$(cat "$askpass_path_file")")" ]
}

@test "case-insensitive retention is normalised once by the orchestration layer" {
  grep -Fq 'RETENTION="${RETENTION_RAW,,}"' "$PRUNE_SCRIPT"
  ! grep -Fq 'RETENTION="${RETENTION,,}"' "$PLAN_SCRIPT"
}

@test "default branch comes from repository context with ref fallback" {
  # shellcheck disable=SC2016
  grep -Fq 'DEFAULT_BRANCH_INPUT: ${{ github.event.repository.default_branch }}' "$ACTION_FILE"
  grep -Fq 'DEFAULT_BRANCH="${DEFAULT_BRANCH_INPUT:-${GITHUB_REF_NAME:-}}"' "$PRUNE_SCRIPT"
  ! grep -Fq -- '--branch main' "$PRUNE_SCRIPT"
}

@test "apt-prune-select-versions remains directly tested and syntax-valid" {
  [ -f "$SELECT_SCRIPT" ]
  bash -n "$SELECT_SCRIPT"
}

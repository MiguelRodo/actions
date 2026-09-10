#!/usr/bin/env bats

# Behavioural tests for the release guards that keep releases and floating tags
# on main. Real temporary git repositories are used so that the ancestry
# direction regression from issue #114 is genuinely exercised.

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ANCESTRY="$ROOT_DIR/scripts/check-release-ancestry.sh"
REQUIRED_CI="$ROOT_DIR/scripts/check-required-ci.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"

setup() {
  REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO_DIR"
  cd "$REPO_DIR" || return 1

  git init --quiet --initial-branch=main .
  git config user.email "test@example.com"
  git config user.name "Test User"

  echo "base" > file.txt
  git add file.txt
  git commit --quiet -m "Base commit on main"
  MAIN_SHA=$(git rev-parse HEAD)

  # A feature branch commit that is ahead of main and never merged.
  git checkout --quiet -b feature
  echo "feature" >> file.txt
  git commit --quiet -am "Feature commit ahead of main"
  FEATURE_SHA=$(git rev-parse HEAD)

  git checkout --quiet main

  # Emulate the remote-tracking ref the workflow validates against.
  git update-ref refs/remotes/origin/main "$MAIN_SHA"

  export MAIN_SHA FEATURE_SHA
}

# ---------------------------------------------------------------------------
# Ancestry guard
# ---------------------------------------------------------------------------

@test "a commit already merged into main can be released" {
  run "$ANCESTRY" "$MAIN_SHA" origin/main
  [ "$status" -eq 0 ]
  [[ "$output" == *"is on 'origin/main'"* ]]
}

@test "a feature-branch-only commit cannot be released" {
  run "$ANCESTRY" "$FEATURE_SHA" origin/main
  [ "$status" -eq 1 ]
  [[ "$output" == *"not reachable from 'origin/main'"* ]]
}

@test "an ancestor of main released after further main commits still passes" {
  echo "more" >> file.txt
  git commit --quiet -am "Later commit on main"
  git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"

  run "$ANCESTRY" "$MAIN_SHA" origin/main
  [ "$status" -eq 0 ]
}

@test "ancestry check fails for an unresolvable commit" {
  run "$ANCESTRY" "0000000000000000000000000000000000000000" origin/main
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not resolve commit"* ]]
}

@test "ancestry check fails when the main ref is missing" {
  run "$ANCESTRY" "$MAIN_SHA" origin/does-not-exist
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not resolve release branch"* ]]
}

@test "ancestry check requires a commit argument" {
  run "$ANCESTRY"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

# ---------------------------------------------------------------------------
# Required CI guard
# ---------------------------------------------------------------------------

@test "required CI guard passes when the required check succeeded" {
  run bash -c 'echo "{\"check_runs\":[{\"name\":\"BATS unit tests (shell scripts)\",\"status\":\"completed\",\"conclusion\":\"success\"}]}" | "'"$REQUIRED_CI"'" "BATS unit tests (shell scripts)"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"succeeded for the release commit"* ]]
}

@test "required CI guard fails when the required check failed" {
  run bash -c 'echo "{\"check_runs\":[{\"name\":\"BATS unit tests (shell scripts)\",\"status\":\"completed\",\"conclusion\":\"failure\"}]}" | "'"$REQUIRED_CI"'" "BATS unit tests (shell scripts)"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"did not succeed"* ]]
}

@test "required CI guard fails when the required check is still running" {
  run bash -c 'echo "{\"check_runs\":[{\"name\":\"BATS unit tests (shell scripts)\",\"status\":\"in_progress\",\"conclusion\":null}]}" | "'"$REQUIRED_CI"'" "BATS unit tests (shell scripts)"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"did not succeed"* ]]
}

@test "required CI guard fails when the required check never ran" {
  run bash -c 'echo "{\"check_runs\":[{\"name\":\"Some other check\",\"status\":\"completed\",\"conclusion\":\"success\"}]}" | "'"$REQUIRED_CI"'" "BATS unit tests (shell scripts)"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"has not run"* ]]
}

@test "required CI guard fails on an unreadable payload" {
  run bash -c 'echo "not json" | "'"$REQUIRED_CI"'" "BATS unit tests (shell scripts)"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not read check runs"* ]]
}

# ---------------------------------------------------------------------------
# Workflow wiring
# ---------------------------------------------------------------------------

@test "release workflow checks out main for manual dispatch" {
  run grep -F "ref: \${{ github.event_name == 'workflow_dispatch' && 'main' || github.ref }}" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "release workflow validates ancestry for every trigger" {
  run grep -F './scripts/check-release-ancestry.sh "$RELEASE_SHA" origin/main' "$WORKFLOW"
  [ "$status" -eq 0 ]

  # The guard must not be gated on a single event type.
  block=$(awk '/name: Verify Release Commit Is On main/{found=1; next} found && /^      - name:/{exit} found' "$WORKFLOW")
  [ -n "$block" ]
  run grep -F 'if:' <<< "$block"
  [ "$status" -ne 0 ]
}

@test "release workflow no longer accepts either ancestry direction" {
  run grep -F 'git merge-base --is-ancestor origin/main' "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "release workflow verifies required CI before moving floating tags" {
  ci_line=$(grep -n 'check-required-ci.sh' "$WORKFLOW" | head -n 1 | cut -d: -f1)
  tag_line=$(grep -n 'Update Floating Major and Minor Tags' "$WORKFLOW" | head -n 1 | cut -d: -f1)
  [ -n "$ci_line" ]
  [ -n "$tag_line" ]
  [ "$ci_line" -lt "$tag_line" ]
}

@test "release workflow moves floating tags after the release is created" {
  release_line=$(grep -n 'Create GitHub Release' "$WORKFLOW" | head -n 1 | cut -d: -f1)
  tag_line=$(grep -n 'Update Floating Major and Minor Tags' "$WORKFLOW" | head -n 1 | cut -d: -f1)
  [ "$release_line" -lt "$tag_line" ]
}

@test "release workflow pins floating tags to the validated commit" {
  run grep -F 'git tag -f "$MINOR" "$RELEASE_SHA"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -F 'git tag -f "$MAJOR" "$RELEASE_SHA"' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

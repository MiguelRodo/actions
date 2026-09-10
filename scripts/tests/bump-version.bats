#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bump-version.sh"

setup() {
  REMOTE_REPO="$BATS_TEST_TMPDIR/remote.git"
  WORK_REPO="$BATS_TEST_TMPDIR/work"
  git init --quiet --bare "$REMOTE_REPO"
  git init --quiet --initial-branch=main "$WORK_REPO"
  git -C "$WORK_REPO" config user.email "test@example.com"
  git -C "$WORK_REPO" config user.name "Test User"
  printf 'initial\n' > "$WORK_REPO/README.md"
  git -C "$WORK_REPO" add README.md
  git -C "$WORK_REPO" commit --quiet -m "Initial commit"
  git -C "$WORK_REPO" remote add origin "$REMOTE_REPO"
  git -C "$WORK_REPO" push --quiet -u origin main
}

run_bump() {
  run bash -c 'cd "$1"; shift; "$@"' _ "$WORK_REPO" "$SCRIPT" "$@"
}

@test "fails with missing arguments" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]

  run bash "$SCRIPT" v1.2.3
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

@test "rejects malformed and injection-shaped versions without changing refs" {
  for version in 1.2.3 v1.2 v1.2.x v1.2.3.4 v1.2.3-beta 'v1.2.3;touch-pwned'; do
    run_bump "$version" my-action
    [ "$status" -eq 1 ]
    [[ "$output" == *"semantic format"* ]]
  done

  [ -z "$(git -C "$WORK_REPO" tag --list)" ]
  [ ! -e "$WORK_REPO/touch-pwned" ]
}

@test "creates annotated exact and floating tags in the local and remote repositories" {
  run_bump v10.20.300 action1 action2
  [ "$status" -eq 0 ]
  [[ "$output" == *"action1,action2"* ]]

  head_sha="$(git -C "$WORK_REPO" rev-parse HEAD)"
  for tag in v10.20.300 v10.20 v10; do
    [ "$(git -C "$WORK_REPO" rev-list -n 1 "$tag")" = "$head_sha" ]
    [ "$(git --git-dir="$REMOTE_REPO" rev-list -n 1 "$tag")" = "$head_sha" ]
  done

  [ "$(git -C "$WORK_REPO" cat-file -t v10.20.300)" = "tag" ]
}

@test "tag annotation preserves adversarial action names as data" {
  action_name='quote '"'"'; $(touch should-not-exist); C:\path; {"json":true}'

  run_bump v1.2.3 "$action_name"
  [ "$status" -eq 0 ]
  [ ! -e "$WORK_REPO/should-not-exist" ]

  message="$(git -C "$WORK_REPO" tag -l --format='%(contents)' v1.2.3)"
  [[ "$message" == *"$action_name"* ]]
}

@test "an existing release tag on a different commit is rejected without moving remote refs" {
  run_bump v2.3.4 first-release
  [ "$status" -eq 0 ]
  original_sha="$(git --git-dir="$REMOTE_REPO" rev-list -n 1 v2.3.4)"

  printf 'second\n' >> "$WORK_REPO/README.md"
  git -C "$WORK_REPO" add README.md
  git -C "$WORK_REPO" commit --quiet -m "Second commit"

  run_bump v2.3.4 second-release
  [ "$status" -ne 0 ]
  [ "$(git --git-dir="$REMOTE_REPO" rev-list -n 1 v2.3.4)" = "$original_sha" ]
  [ "$(git --git-dir="$REMOTE_REPO" rev-list -n 1 v2.3)" = "$original_sha" ]
  [ "$(git --git-dir="$REMOTE_REPO" rev-list -n 1 v2)" = "$original_sha" ]
}

#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ENSURE_TAG="$ROOT_DIR/scripts/ensure-release-tag.sh"
PROMOTE_TAGS="$ROOT_DIR/scripts/update-floating-release-tags.sh"

setup() {
  REMOTE_DIR="$BATS_TEST_TMPDIR/remote.git"
  WORK_DIR="$BATS_TEST_TMPDIR/work"

  git init --quiet --bare "$REMOTE_DIR"
  git clone --quiet "$REMOTE_DIR" "$WORK_DIR"
  cd "$WORK_DIR" || return 1
  git config user.name "Test User"
  git config user.email "test@example.com"

  echo base > file.txt
  git add file.txt
  git commit --quiet -m "Base"
  OLD_SHA="$(git rev-parse HEAD)"

  git tag -a v1.0.0 -m v1.0.0
  git tag -a v1.0 -m v1.0
  git tag -a v1 -m v1
  git tag -a latest -m latest
  git push --quiet origin HEAD:main v1.0.0 v1.0 v1 latest

  echo next >> file.txt
  git commit --quiet -am "Next"
  NEW_SHA="$(git rev-parse HEAD)"
}

remote_tag_commit() {
  git ls-remote origin "refs/tags/$1^{}" | awk '{print $1}'
}

@test "late release failure leaves floating aliases on the previous release" {
  run bash "$ENSURE_TAG" v1.1.0
  [ "$status" -eq 0 ]

  # A build/publication failure here means the promotion step is never run.
  [ "$(remote_tag_commit v1.1.0)" = "$NEW_SHA" ]
  [ "$(remote_tag_commit v1)" = "$OLD_SHA" ]
  [ "$(remote_tag_commit v1.0)" = "$OLD_SHA" ]
  [ "$(remote_tag_commit latest)" = "$OLD_SHA" ]

  run bash "$PROMOTE_TAGS" v1.1.0
  [ "$status" -eq 0 ]
  [ "$(remote_tag_commit v1)" = "$NEW_SHA" ]
  [ "$(remote_tag_commit v1.1)" = "$NEW_SHA" ]
  [ "$(remote_tag_commit latest)" = "$NEW_SHA" ]
  [ "$(remote_tag_commit v1.0)" = "$OLD_SHA" ]
}

@test "existing specific tag pointing elsewhere is rejected" {
  git tag -a v1.2.0 -m v1.2.0 "$OLD_SHA"
  git push --quiet origin v1.2.0
  git tag -d v1.2.0 >/dev/null

  run bash "$ENSURE_TAG" v1.2.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"not the validated release commit"* ]]
}

@test "all reusable release actions promote floating tags after publication" {
  go="$ROOT_DIR/go-version-release/action.yml"
  rust="$ROOT_DIR/rust-version-release/action.yml"
  r="$ROOT_DIR/r-version-release/action.yml"
  generic="$ROOT_DIR/version-release/action.yml"

  [ "$(grep -n 'Publish Debian packages to apt repository' "$go" | tail -1 | cut -d: -f1)" -lt "$(grep -n 'Update floating major, minor and latest tags' "$go" | cut -d: -f1)" ]
  [ "$(grep -n 'Publish Debian packages to apt repository' "$rust" | tail -1 | cut -d: -f1)" -lt "$(grep -n 'Update floating major, minor and latest tags' "$rust" | cut -d: -f1)" ]
  [ "$(grep -n 'Create GitHub Release' "$r" | tail -1 | cut -d: -f1)" -lt "$(grep -n 'Update floating major, minor and latest tags' "$r" | cut -d: -f1)" ]
  [ "$(grep -n 'Create GitHub Release' "$generic" | tail -1 | cut -d: -f1)" -lt "$(grep -n 'Update floating major, minor and latest tags' "$generic" | cut -d: -f1)" ]
}

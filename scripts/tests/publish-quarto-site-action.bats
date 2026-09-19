#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/ensure-gh-pages-branch.sh"
ACTION_FILE="$REPO_ROOT/publish-quarto-site/action.yml"

setup() {
  TEST_ROOT="$(mktemp -d)"
  REMOTE="$TEST_ROOT/remote.git"
  WORK="$TEST_ROOT/work"

  git init --bare "$REMOTE" >/dev/null
  git init "$WORK" >/dev/null
  cd "$WORK"
  git config user.name "Test User"
  git config user.email "test@example.com"
  echo "main" > content.txt
  git add content.txt
  git commit -m "Initial commit" >/dev/null
  git branch -M main
  git remote add origin "$REMOTE"
  git push -u origin main >/dev/null
}

teardown() {
  cd /
  rm -rf "$TEST_ROOT"
}

@test "publish-quarto-site creates gh-pages and returns to the caller branch" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Creating gh-pages branch"* ]]

  run git rev-parse --abbrev-ref HEAD
  [ "$status" -eq 0 ]
  [ "$output" = "main" ]

  run git ls-remote --exit-code --heads origin refs/heads/gh-pages
  [ "$status" -eq 0 ]

  run git show gh-pages:README.md
  [ "$status" -eq 0 ]
  [ "$output" = "# GitHub Pages" ]

  [ -f content.txt ]
}

@test "publish-quarto-site leaves an existing gh-pages branch unchanged" {
  git push origin main:gh-pages >/dev/null
  before="$(git ls-remote origin refs/heads/gh-pages | cut -f1)"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gh-pages branch already exists"* ]]

  after="$(git ls-remote origin refs/heads/gh-pages | cut -f1)"
  [ "$after" = "$before" ]

  run git rev-parse --abbrev-ref HEAD
  [ "$status" -eq 0 ]
  [ "$output" = "main" ]
}

@test "publish-quarto-site action delegates branch initialisation to the tested helper" {
  run grep -F 'run: bash "$GITHUB_ACTION_PATH/../scripts/ensure-gh-pages-branch.sh"' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'git checkout --orphan gh-pages' "$ACTION_FILE"
  [ "$status" -ne 0 ]
}

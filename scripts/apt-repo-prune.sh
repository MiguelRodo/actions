#!/usr/bin/env bash

set -euo pipefail

: "${RETENTION_RAW:?RETENTION_RAW must be set}"
: "${PUSH_TOKEN:?PUSH_TOKEN must be set}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"
: "${GITHUB_SERVER_URL:?GITHUB_SERVER_URL must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/git-auth-askpass.sh
source "$SCRIPT_DIR/git-auth-askpass.sh"
# shellcheck source=scripts/apt-repository-metadata.sh
source "$SCRIPT_DIR/apt-repository-metadata.sh"

RETENTION="${RETENTION_RAW,,}"
DEFAULT_BRANCH="${DEFAULT_BRANCH_INPUT:-${GITHUB_REF_NAME:-}}"
if [[ -z "$DEFAULT_BRANCH" ]]; then
  echo "Error: could not determine the repository default branch." >&2
  exit 1
fi

APT_REPO_DIR=""
PATHS_TO_REMOVE_FILE=""
PLAN_OUTPUT=""
cleanup() {
  [[ -n "$APT_REPO_DIR" ]] && rm -rf "$APT_REPO_DIR"
  [[ -n "$PATHS_TO_REMOVE_FILE" ]] && rm -f "$PATHS_TO_REMOVE_FILE"
  [[ -n "$PLAN_OUTPUT" ]] && rm -f "$PLAN_OUTPUT"
  cleanup_git_askpass
  apt_repository_cleanup_signing
}
trap cleanup EXIT

apt_repository_require_tools
apt_repository_setup_signing

export GIT_TOKEN_FOR_ASKPASS="$PUSH_TOKEN"
setup_git_askpass

REMOTE_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}.git"
APT_REPO_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/apt-repo-prune-XXXXXX")"
git clone \
  --branch "$DEFAULT_BRANCH" \
  --single-branch \
  "$REMOTE_URL" \
  "$APT_REPO_DIR"

PLAN_OUTPUT="$(mktemp "${RUNNER_TEMP:-/tmp}/apt-prune-plan-output-XXXXXX")"
GITHUB_OUTPUT="$PLAN_OUTPUT" "$SCRIPT_DIR/apt-prune-plan.sh" \
  "$RETENTION" "$APT_REPO_DIR" "$GITHUB_REPOSITORY" "$DEFAULT_BRANCH"

if grep -Fxq 'should_prune=false' "$PLAN_OUTPUT"; then
  echo "No history rewrite or push required."
  exit 0
fi

if ! grep -Fxq 'should_prune=true' "$PLAN_OUTPUT"; then
  echo "Error: prune planner did not return a valid decision." >&2
  exit 1
fi

PATHS_TO_REMOVE_FILE="$(sed -n 's/^paths_to_remove_file=//p' "$PLAN_OUTPUT")"
if [[ -z "$PATHS_TO_REMOVE_FILE" || ! -s "$PATHS_TO_REMOVE_FILE" ]]; then
  echo "Error: prune planner did not return a non-empty removal list." >&2
  exit 1
fi

(
  cd "$APT_REPO_DIR"
  ROOT_COMMIT="$(git rev-list --max-parents=0 HEAD)"
  if git ls-tree -r --name-only "$ROOT_COMMIT" | grep -qFx -f "$PATHS_TO_REMOVE_FILE"; then
    echo "Warning: one or more files to be pruned exist in the root commit." >&2
    echo "  The root commit SHA will change after the history rewrite." >&2
  fi
)

(
  cd "$APT_REPO_DIR"
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

  if ! command -v git-filter-repo >/dev/null 2>&1; then
    pip install git-filter-repo --quiet
  fi

  git filter-repo \
    --invert-paths \
    --paths-from-file "$PATHS_TO_REMOVE_FILE" \
    --force

  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
  else
    git remote add origin "$REMOTE_URL"
  fi
)

REPO_OWNER="${GITHUB_REPOSITORY%%/*}"
REPO_NAME="${GITHUB_REPOSITORY##*/}"
apt_repository_regenerate_metadata "$APT_REPO_DIR" "$REPO_OWNER" "$REPO_NAME" clear

(
  cd "$APT_REPO_DIR"
  git add -A

  if git diff --cached --quiet; then
    echo "No apt metadata changes required after pruning."
  else
    git commit -m "Prune apt repository: apply '${RETENTION}' retention policy"
  fi

  git push --force origin "HEAD:${DEFAULT_BRANCH}"
)

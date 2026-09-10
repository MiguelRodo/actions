#!/usr/bin/env bash
set -euo pipefail

RETENTION="${1:?Usage: apt-prune-plan.sh RETENTION REPO_DIR REPO_LABEL DEFAULT_BRANCH}"
APT_REPO_DIR="${2:?Usage: apt-prune-plan.sh RETENTION REPO_DIR REPO_LABEL DEFAULT_BRANCH}"
REPO_LABEL="${3:?Usage: apt-prune-plan.sh RETENTION REPO_DIR REPO_LABEL DEFAULT_BRANCH}"
DEFAULT_BRANCH="${4:?Usage: apt-prune-plan.sh RETENTION REPO_DIR REPO_LABEL DEFAULT_BRANCH}"

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RETENTION="${RETENTION,,}"

if [[ ! -d "$APT_REPO_DIR/pool/main" ]]; then
  printf "Nothing to prune: pool/main/ not found in '%s' - repository has no packages.\n" "$REPO_LABEL"
  rm -rf "$APT_REPO_DIR"
  printf 'should_prune=false\n' >> "$GITHUB_OUTPUT"
  exit 0
fi

if [[ ! -d "$APT_REPO_DIR/dists/stable" ]]; then
  printf "Error: expected dists/stable/ directory not found in '%s'.\n" "$REPO_LABEL" >&2
  printf '  This action is designed for repositories managed by the go-version-release action.\n' >&2
  rm -rf "$APT_REPO_DIR"
  exit 1
fi

PATHS_TO_REMOVE_FILE="$(mktemp "${RUNNER_TEMP:-/tmp}/apt-prune-paths-XXXXXX")"
bash "$SCRIPT_DIR/apt-prune-select-versions.sh" \
  "$RETENTION" "$APT_REPO_DIR" > "$PATHS_TO_REMOVE_FILE"

if [[ ! -s "$PATHS_TO_REMOVE_FILE" ]]; then
  printf "Nothing to prune: apt repository already satisfies the '%s' retention policy.\n" "$RETENTION"
  rm -f "$PATHS_TO_REMOVE_FILE"
  rm -rf "$APT_REPO_DIR"
  printf 'should_prune=false\n' >> "$GITHUB_OUTPUT"
  exit 0
fi

printf 'Pruning the following files from history:\n'
cat "$PATHS_TO_REMOVE_FILE"

{
  printf 'should_prune=true\n'
  printf 'apt_repo_dir=%s\n' "$APT_REPO_DIR"
  printf 'paths_to_remove_file=%s\n' "$PATHS_TO_REMOVE_FILE"
  printf 'default_branch=%s\n' "$DEFAULT_BRANCH"
} >> "$GITHUB_OUTPUT"

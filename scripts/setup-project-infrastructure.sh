#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/setup-project-files.sh
source "$SCRIPT_DIR/setup-project-files.sh"
# shellcheck source=scripts/git-auth-askpass.sh
source "$SCRIPT_DIR/git-auth-askpass.sh"

: "${WORKING_REPO_INPUT:?WORKING_REPO_INPUT is required}"
: "${TEMPLATE_REPO_INPUT:?TEMPLATE_REPO_INPUT is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"

BUILDER_REPO_REF="${BUILDER_REPO_INPUT:-$WORKING_REPO_INPUT}"
CONFIG_REPO_REF="${CONFIG_REPO_INPUT:-$WORKING_REPO_INPUT}"
RENV_PKGS_INPUT="${RENV_PKGS_INPUT:-}"
RENV_REPOS_INPUT="${RENV_REPOS_INPUT:-}"
REPOS_LIST_INPUT="${REPOS_LIST_INPUT:-}"

parse_repo_ref "$WORKING_REPO_INPUT"
WORKING_REPO="$PARSED_REPO"
WORKING_BRANCH="$PARSED_BRANCH"
WORKING_REF="$WORKING_REPO${WORKING_BRANCH:+@$WORKING_BRANCH}"
WORKING_KEY="$WORKING_REPO|$WORKING_BRANCH"

parse_repo_ref "$TEMPLATE_REPO_INPUT"
TEMPLATE_REPO="$PARSED_REPO"
TEMPLATE_BRANCH="$PARSED_BRANCH"
TEMPLATE_REF="$TEMPLATE_REPO${TEMPLATE_BRANCH:+@$TEMPLATE_BRANCH}"
TEMPLATE_KEY="$TEMPLATE_REPO|$TEMPLATE_BRANCH"

parse_repo_ref "$BUILDER_REPO_REF"
BUILDER_REPO="$PARSED_REPO"
BUILDER_BRANCH="$PARSED_BRANCH"
BUILDER_REF="$BUILDER_REPO${BUILDER_BRANCH:+@$BUILDER_BRANCH}"
BUILDER_KEY="$BUILDER_REPO|$BUILDER_BRANCH"
BUILDER_OWNER="${BUILDER_REPO%%/*}"
BUILDER_NAME="${BUILDER_REPO##*/}"

parse_repo_ref "$CONFIG_REPO_REF"
CONFIG_REPO="$PARSED_REPO"
CONFIG_BRANCH="$PARSED_BRANCH"
CONFIG_REF="$CONFIG_REPO${CONFIG_BRANCH:+@$CONFIG_BRANCH}"
CONFIG_KEY="$CONFIG_REPO|$CONFIG_BRANCH"

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
export GIT_TOKEN_FOR_ASKPASS="$GH_TOKEN"
trap cleanup_git_askpass EXIT
setup_git_askpass

WORKSPACE_ROOT="${SETUP_PROJECT_WORKSPACE_ROOT:-${RUNNER_TEMP:-/tmp}/project-setup-workspace}"
rm -rf "$WORKSPACE_ROOT"
mkdir -p "$WORKSPACE_ROOT/control"

WORKING_DIR="working_repo_dir"
BUILDER_DIR="builder_repo_dir"
CONFIG_DIR="config_repo_dir"
TEMPLATE_DIR="template_repo_dir"

if [[ "$BUILDER_KEY" == "$WORKING_KEY" ]]; then
  BUILDER_DIR="$WORKING_DIR"
fi
if [[ "$CONFIG_KEY" == "$WORKING_KEY" ]]; then
  CONFIG_DIR="$WORKING_DIR"
elif [[ "$CONFIG_KEY" == "$BUILDER_KEY" ]]; then
  CONFIG_DIR="$BUILDER_DIR"
fi
if [[ "$TEMPLATE_KEY" == "$WORKING_KEY" ]]; then
  TEMPLATE_DIR="$WORKING_DIR"
elif [[ "$TEMPLATE_KEY" == "$BUILDER_KEY" ]]; then
  TEMPLATE_DIR="$BUILDER_DIR"
elif [[ "$TEMPLATE_KEY" == "$CONFIG_KEY" ]]; then
  TEMPLATE_DIR="$CONFIG_DIR"
fi

{
  printf '%s %s\n' "$WORKING_REF" "$WORKING_DIR"
  if [[ "$BUILDER_DIR" != "$WORKING_DIR" ]]; then
    printf '%s %s\n' "$BUILDER_REF" "$BUILDER_DIR"
  fi
  if [[ "$CONFIG_DIR" != "$WORKING_DIR" && "$CONFIG_DIR" != "$BUILDER_DIR" ]]; then
    printf '%s %s\n' "$CONFIG_REF" "$CONFIG_DIR"
  fi
  if [[ "$TEMPLATE_DIR" != "$WORKING_DIR" && "$TEMPLATE_DIR" != "$BUILDER_DIR" && "$TEMPLATE_DIR" != "$CONFIG_DIR" ]]; then
    printf '%s %s\n' "$TEMPLATE_REF" "$TEMPLATE_DIR"
  fi
} > "$WORKSPACE_ROOT/control/repos.list"

(
  cd "$WORKSPACE_ROOT/control"
  repos clone --create --fetch-single
)

TEMPLATE_DEVCONTAINER="$WORKSPACE_ROOT/$TEMPLATE_DIR/.devcontainer"
[[ -d "$TEMPLATE_DEVCONTAINER" ]] || {
  echo "Error: template repo does not contain .devcontainer" >&2
  exit 1
}
if [[ "$TEMPLATE_DIR" != "$BUILDER_DIR" ]]; then
  mkdir -p "$WORKSPACE_ROOT/$BUILDER_DIR/.devcontainer"
  cp -a "$TEMPLATE_DEVCONTAINER/." "$WORKSPACE_ROOT/$BUILDER_DIR/.devcontainer/"
fi

(
  cd "$WORKSPACE_ROOT/$BUILDER_DIR"

  if [[ -n "$RENV_PKGS_INPUT" || -n "$RENV_REPOS_INPUT" ]]; then
    DEVCONTAINER_JSON=".devcontainer/devcontainer.json"
    [[ -f "$DEVCONTAINER_JSON" ]] || {
      echo "Error: template did not provide $DEVCONTAINER_JSON" >&2
      exit 1
    }
    update_renv_cache "$DEVCONTAINER_JSON" "$RENV_PKGS_INPUT" "$RENV_REPOS_INPUT"
  fi

  if [[ "$BUILDER_KEY" != "$WORKING_KEY" ]]; then
    setupmjr repo action prebuild-devcontainer
  fi
)

if [[ "$BUILDER_KEY" != "$WORKING_KEY" ]]; then
  IMAGE_TAG="${BUILDER_BRANCH:-latest}"
  IMAGE_URL="ghcr.io/${BUILDER_OWNER}/${BUILDER_NAME}-${IMAGE_TAG}:latest"
  IMAGE_URL="${IMAGE_URL,,}"
  write_config_devcontainer \
    "$WORKSPACE_ROOT/$CONFIG_DIR/.devcontainer/devcontainer.json" \
    "$IMAGE_URL"
fi

(
  cd "$WORKSPACE_ROOT/$WORKING_DIR"

  if [[ -n "$REPOS_LIST_INPUT" ]]; then
    append_repos_list "repos.list" "$REPOS_LIST_INPUT"
    repos create
  fi

  repos codespace
  repos workspace
)

commit_and_push() {
  local repo_dir="$1"
  local branch="$2"

  (
    cd "$WORKSPACE_ROOT/$repo_dir"
    git add -A
    if git diff --cached --quiet; then
      exit 0
    fi
    git commit -m "chore: setup project infrastructure"
    if [[ -n "$branch" ]]; then
      git push origin HEAD:"$branch"
    else
      git push origin HEAD
    fi
  )
}

commit_and_push "$WORKING_DIR" "$WORKING_BRANCH"
if [[ "$BUILDER_DIR" != "$WORKING_DIR" ]]; then
  commit_and_push "$BUILDER_DIR" "$BUILDER_BRANCH"
fi
if [[ "$CONFIG_DIR" != "$WORKING_DIR" && "$CONFIG_DIR" != "$BUILDER_DIR" ]]; then
  commit_and_push "$CONFIG_DIR" "$CONFIG_BRANCH"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat >> "$GITHUB_STEP_SUMMARY" <<'EOF_SUMMARY'
### 🏗️ Project Infrastructure Established!

The repository branches, devcontainer pipelines, and multi-repo architectures have been cross-linked and configured upstream.

#### 🏁 Next Steps to Enter Your Environment:
1. **Trigger Container Prebuild:** Go to your builder repository action panel and ensure the container prebuild workflow is building.
2. **Launch Project:** Once the image lands successfully on GHCR, head back to your working branch and launch the environment.
EOF_SUMMARY
fi

echo "Done!"

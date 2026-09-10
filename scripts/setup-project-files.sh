#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
  printf 'Error: %s\n' "$1" >&2
  return 1
}

parse_repo_ref() {
  local input="${1:-}"
  local repo branch=""

  [[ -n "$input" ]] || die "repository reference must not be empty."

  repo="${input%%@*}"
  if [[ "$input" == *@* ]]; then
    branch="${input#*@}"
    [[ -n "$branch" ]] || die "branch must not be empty after '@'."
  fi

  [[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] ||
    die "repository must use owner/repo syntax."

  if [[ -n "$branch" ]] && ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
    die "invalid branch name '$branch'."
  fi

  PARSED_REPO="$repo"
  PARSED_BRANCH="$branch"
}

update_renv_cache() {
  local devcontainer_json="$1"
  local packages_input="$2"
  local repositories_input="$3"
  local packages_json repositories_json temp_json

  packages_json="$("$SCRIPT_DIR/parse-delimited-json.sh" "$packages_input")"
  repositories_json="$("$SCRIPT_DIR/parse-delimited-json.sh" "$repositories_input")"
  temp_json="$(mktemp "${devcontainer_json}.XXXXXX")"
  trap 'rm -f "$temp_json"' RETURN

  sed -E 's/(^|[^:])\/\/.*/\1/g' "$devcontainer_json" |
    jq --argjson pkgs "$packages_json" \
      --argjson repos "$repositories_json" \
      'if .features then
        if .features | has("ghcr.io/miguelrodo/devcontainers/renv-cache:latest") then
          .features["ghcr.io/miguelrodo/devcontainers/renv-cache:latest"].pkg = $pkgs |
          .features["ghcr.io/miguelrodo/devcontainers/renv-cache:latest"].repos = $repos
        else
          .features["ghcr.io/miguelrodo/devcontainers/renv-cache:latest"] = {
            "pkg": $pkgs,
            "repos": $repos
          }
        end
      else
        .features = {
          "ghcr.io/miguelrodo/devcontainers/renv-cache:latest": {
            "pkg": $pkgs,
            "repos": $repos
          }
        }
      end' > "$temp_json"

  mv "$temp_json" "$devcontainer_json"
  trap - RETURN
}

write_builder_workflow() {
  local workflow_file="$1"

  mkdir -p "$(dirname "$workflow_file")"
  cat > "$workflow_file" <<'YAML'
name: Pre-build Dev Container
on:
  push:
    branches:
      - "**"
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
    steps:
      - uses: actions/checkout@v6
      - uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
YAML
}

write_config_devcontainer() {
  local devcontainer_json="$1"
  local image_url="$2"

  mkdir -p "$(dirname "$devcontainer_json")"
  jq -n --arg image "$image_url" '{image: $image}' > "$devcontainer_json"
}

append_repos_list() {
  local repos_file="$1"
  local repos_input="$2"
  local repos_json

  repos_json="$("$SCRIPT_DIR/parse-delimited-json.sh" "$repos_input")"
  if ! jq -e 'all(.[]; (explode | all(.[]; . >= 32 and . != 127)))' <<<"$repos_json" >/dev/null; then
    die "repos_list entries must not contain control characters."
  fi

  mkdir -p "$(dirname "$repos_file")"
  jq -r '.[]' <<<"$repos_json" >> "$repos_file"
}

main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    parse-repo-ref)
      [[ "$#" -eq 1 ]] || die "usage: $0 parse-repo-ref owner/repo[@branch]"
      parse_repo_ref "$1"
      jq -n --arg repo "$PARSED_REPO" --arg branch "$PARSED_BRANCH" \
        '{repo: $repo, branch: $branch}'
      ;;
    update-renv-cache)
      [[ "$#" -eq 3 ]] || die "usage: $0 update-renv-cache FILE PACKAGES REPOSITORIES"
      update_renv_cache "$@"
      ;;
    write-builder-workflow)
      [[ "$#" -eq 1 ]] || die "usage: $0 write-builder-workflow FILE"
      write_builder_workflow "$1"
      ;;
    write-config-devcontainer)
      [[ "$#" -eq 2 ]] || die "usage: $0 write-config-devcontainer FILE IMAGE"
      write_config_devcontainer "$@"
      ;;
    append-repos-list)
      [[ "$#" -eq 2 ]] || die "usage: $0 append-repos-list FILE REPOSITORIES"
      append_repos_list "$@"
      ;;
    *)
      die "unknown command '$command'."
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

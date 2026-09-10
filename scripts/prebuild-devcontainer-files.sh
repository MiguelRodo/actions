#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

resolve_path() {
  local path="${1:-}"
  local subfolder

  [[ -n "$path" ]] || die "devcontainer_path must not be empty."
  [[ "$path" != /* ]] || die "devcontainer_path must be relative to the repository root."
  if ! printf '%s' "$path" |
    jq -eRs 'explode | all(.[]; . >= 32 and . != 127)' >/dev/null; then
    die "devcontainer_path must not contain control characters."
  fi

  while [[ "$path" == ./* ]]; do
    path="${path#./}"
  done
  while [[ "$path" == */ && "$path" != "/" ]]; do
    path="${path%/}"
  done

  [[ -n "$path" && "$path" != "." ]] || die "devcontainer_path must name a directory."
  [[ "/$path/" != *"/../"* ]] || die "devcontainer_path must not traverse outside the repository."

  subfolder="$(dirname -- "$path")"
  if [[ "$subfolder" == "." ]]; then
    subfolder=""
  fi

  jq -n --arg path "$path" --arg subfolder "$subfolder" \
    '{path: $path, subfolder: $subfolder}'
}

update_prebuild_json() {
  local devcontainer_path="$1"
  local image_ref="$2"
  local devcontainer_json="$devcontainer_path/devcontainer.json"
  local prebuild_json="$devcontainer_path/prebuild/devcontainer.json"
  local temp_json

  mkdir -p "$(dirname "$prebuild_json")"
  temp_json="$(mktemp "${prebuild_json}.XXXXXX")"
  trap 'rm -f "$temp_json"' EXIT

  if [[ -f "$prebuild_json" ]]; then
    jq --arg image "$image_ref" '.image = $image' "$prebuild_json" > "$temp_json"
  elif [[ -f "$devcontainer_json" ]]; then
    jq --arg image "$image_ref" \
      '{image: $image, customizations: .customizations}' \
      "$devcontainer_json" > "$temp_json"
  else
    die "No devcontainer.json found at '$devcontainer_json' to copy customizations from."
  fi

  mv "$temp_json" "$prebuild_json"
  trap - EXIT
}

case "${1:-}" in
  resolve)
    [[ "$#" -eq 2 ]] || die "usage: $0 resolve DEVCONTAINER_PATH"
    resolve_path "$2"
    ;;
  update-prebuild-json)
    [[ "$#" -eq 3 ]] || die "usage: $0 update-prebuild-json DEVCONTAINER_PATH IMAGE_REF"
    update_prebuild_json "$2" "$3"
    ;;
  *)
    die "unknown command '${1:-}'."
    ;;
esac

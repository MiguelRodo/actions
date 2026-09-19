#!/bin/bash
# Resolve prebuild-devcontainer's image tag and cache source from one registry read.
# Usage: prebuild-devcontainer-version.sh IMAGE_NAME VERSION TAG BUMP_TYPE VERSION_FORCE GITHUB_REF

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${1:?Usage: prebuild-devcontainer-version.sh IMAGE_NAME VERSION TAG BUMP_TYPE VERSION_FORCE GITHUB_REF}"
RAW_VERSION="${2-}"
RAW_TAG="${3-}"
RAW_BUMP="${4-}"
VERSION_FORCE="${5:-false}"
GITHUB_REF="${6-}"

VERSION_INPUT=$("$SCRIPT_DIR/normalize-action-input.sh" "${RAW_VERSION:-$RAW_TAG}")
BUMP_INPUT=$("$SCRIPT_DIR/normalize-action-input.sh" "$RAW_BUMP")

if [ -n "$VERSION_INPUT" ] && [ -n "$BUMP_INPUT" ]; then
  echo "Error: cannot set both 'version' (or 'tag') and 'bump_type'." >&2
  exit 1
fi

if [ -z "$RAW_VERSION" ] && [ -n "$RAW_TAG" ]; then
  echo "::warning::Input 'tag' is deprecated; use 'version'." >&2
fi

ALL_TAGS=""
LATEST_VERSION_TAGS=""

if [[ "$IMAGE_NAME" == ghcr.io/* ]]; then
  TOKEN="${INPUT_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
  REST="${IMAGE_NAME#ghcr.io/}"
  OWNER="${REST%%/*}"
  PACKAGE="${REST#*/}"
  ENCODED_PACKAGE="${PACKAGE//\//%2F}"

  VERSIONS=$(curl -sf \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/orgs/${OWNER}/packages/container/${ENCODED_PACKAGE}/versions?per_page=100" \
    2>/dev/null || echo "[]")
  if ! jq -e 'type == "array" and length > 0' <<<"$VERSIONS" >/dev/null 2>&1; then
    VERSIONS=$(curl -sf \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/user/packages/container/${ENCODED_PACKAGE}/versions?per_page=100" \
      2>/dev/null || echo "[]")
  fi

  ALL_TAGS=$(jq -r '.[].metadata.container.tags[]? // empty' <<<"$VERSIONS" 2>/dev/null || true)
  LATEST_VERSION_TAGS=$(jq -r '
    .[]
    | select(.metadata.container.tags != null)
    | select(.metadata.container.tags | index("latest"))
    | .metadata.container.tags[]?
  ' <<<"$VERSIONS" 2>/dev/null || true)
else
  ALL_TAGS=$(skopeo list-tags --authfile ~/.docker/config.json "docker://${IMAGE_NAME}" 2>/dev/null \
    | jq -r '.Tags[]?' 2>/dev/null || true)
fi

latest_semver_tag() {
  printf '%s\n' "$1" \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -n 1 || true
}

if [ -n "$BUMP_INPUT" ]; then
  PREV_TAG=$(latest_semver_tag "$LATEST_VERSION_TAGS")
  if [ -z "$PREV_TAG" ]; then
    PREV_TAG=$(latest_semver_tag "$ALL_TAGS")
  fi
  if [ -z "$PREV_TAG" ]; then
    echo "Notice: Could not determine current version from registry. Defaulting to v0.0.0 for initial bump." >&2
    PREV_TAG="v0.0.0"
  fi

  VERSION=$("$SCRIPT_DIR/apply-version-bump.sh" "$BUMP_INPUT" "${PREV_TAG#v}")
  IMAGE_TAG="v${VERSION}"
elif [ -n "$VERSION_INPUT" ]; then
  IMAGE_TAG="${VERSION_INPUT#v}"
  if [[ "$IMAGE_TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    IMAGE_TAG="v${IMAGE_TAG}"
  fi
elif [[ "$GITHUB_REF" == refs/tags/* ]]; then
  IMAGE_TAG="${GITHUB_REF#refs/tags/}"
else
  echo "Error: no version source available. Provide 'bump_type', 'version', or trigger from a git tag." >&2
  exit 1
fi

TAG_PREFIX=""
NEW_VERSION=""
if [[ "$IMAGE_TAG" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  NEW_VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
elif [[ "$IMAGE_TAG" =~ ^(.+)-v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  TAG_PREFIX="${BASH_REMATCH[1]}-"
  NEW_VERSION="${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.${BASH_REMATCH[4]}"
fi

if [ "$VERSION_FORCE" = "true" ]; then
  echo "version_force=true; skipping version progression check." >&2
elif [ -z "$NEW_VERSION" ]; then
  echo "Tag '${IMAGE_TAG}' is not a SemVer tag; skipping version progression check." >&2
else
  if [ -z "$TAG_PREFIX" ]; then
    SEMVER_GREP='^v[0-9]+\.[0-9]+\.[0-9]+$'
  else
    SEMVER_GREP="^${TAG_PREFIX}v[0-9]+\\.[0-9]+\\.[0-9]+\$"
  fi

  PREV_VERSION=$(printf '%s\n' "$ALL_TAGS" \
    | grep -E "$SEMVER_GREP" \
    | grep -vxF "$IMAGE_TAG" \
    | sed "s/^${TAG_PREFIX}v//" \
    | sort -V \
    | tail -n 1 || true)

  if [ -z "$PREV_VERSION" ]; then
    echo "No previous SemVer version found for image; skipping version progression check." >&2
  else
    echo "Previous version: ${PREV_VERSION}, new version: ${NEW_VERSION}" >&2
    echo "To skip this check, set version_force: 'true'." >&2
    "$SCRIPT_DIR/check-version-progression.sh" "$NEW_VERSION" "$PREV_VERSION" >&2
  fi
fi

if [ -z "$ALL_TAGS" ]; then
  echo "No existing tags found in registry. Falling back to latest (will gracefully cache-miss)." >&2
  CACHE_TAG="latest"
elif grep -qFx "latest" <<<"$ALL_TAGS"; then
  echo "Found 'latest' tag. Using as cache source." >&2
  CACHE_TAG="latest"
else
  if [ -z "$TAG_PREFIX" ]; then
    SEMVER_GREP='^v[0-9]+\.[0-9]+\.[0-9]+$'
  else
    SEMVER_GREP="^${TAG_PREFIX}v[0-9]+\\.[0-9]+\\.[0-9]+\$"
  fi

  PREV_TAG=$(printf '%s\n' "$ALL_TAGS" \
    | grep -E "$SEMVER_GREP" \
    | grep -vxF "$IMAGE_TAG" \
    | sort -V \
    | tail -n 1 || true)

  if [ -n "$PREV_TAG" ]; then
    echo "Found previous SemVer tag '${PREV_TAG}'. Using as cache source." >&2
    CACHE_TAG="$PREV_TAG"
  else
    FIRST_TAG=$(printf '%s\n' "$ALL_TAGS" | sed -n '/[^[:space:]]/{p;q;}')
    if [ -n "$FIRST_TAG" ]; then
      echo "No 'latest' or previous SemVer tag found. Using most recent tag '${FIRST_TAG}' as cache source." >&2
      CACHE_TAG="$FIRST_TAG"
    else
      echo "No usable tags found. Falling back to latest." >&2
      CACHE_TAG="latest"
    fi
  fi
fi

jq -n --arg image_tag "$IMAGE_TAG" --arg cache_from "${IMAGE_NAME}:${CACHE_TAG}" \
  '{image_tag: $image_tag, cache_from: $cache_from}'

#!/bin/bash
set -euo pipefail

TAG="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$TAG" ]; then
  echo "Usage: ensure-release-tag.sh <VERSION_TAG>" >&2
  exit 1
fi

HEAD_SHA="$(git rev-parse HEAD)"

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  git fetch --force --no-tags origin "refs/tags/${TAG}:refs/tags/${TAG}"
  bash "$SCRIPT_DIR/check-release-tag.sh" "$TAG" "$HEAD_SHA"
  exit 0
fi

if git show-ref --tags --verify --quiet "refs/tags/${TAG}"; then
  bash "$SCRIPT_DIR/check-release-tag.sh" "$TAG" "$HEAD_SHA"
else
  git tag -a "$TAG" -m "Release $TAG"
fi

git push origin "refs/tags/${TAG}"

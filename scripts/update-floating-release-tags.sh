#!/bin/bash
set -euo pipefail

TAG="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: update-floating-release-tags.sh <vX.Y.Z>" >&2
  exit 1
fi

HEAD_SHA="$(git rev-parse HEAD)"
bash "$SCRIPT_DIR/check-release-tag.sh" "$TAG" "$HEAD_SHA"

MAJOR="${TAG%%.*}"
MINOR="${TAG%.*}"

git tag -fa "$MINOR" -m "Update $MINOR to point to $TAG"
git tag -fa "$MAJOR" -m "Update $MAJOR to point to $TAG"
git tag -fa latest -m "Update latest to point to $TAG"
git push --atomic --force origin \
  "refs/tags/$MINOR" \
  "refs/tags/$MAJOR" \
  refs/tags/latest

#!/bin/bash
# Usage: check-release-tag.sh <VERSION_TAG> <RELEASE_COMMIT>
#
# Verifies that an existing version tag resolves to the validated release
# commit. GitHub ignores target_commitish when a release tag already exists, so
# reusing a tag that points elsewhere could publish a release from the wrong
# commit even after the intended commit passed ancestry and CI validation.

set -euo pipefail

VERSION="${1:-}"
RELEASE_COMMIT="${2:-}"

if [ -z "$VERSION" ] || [ -z "$RELEASE_COMMIT" ]; then
  echo "Usage: check-release-tag.sh <VERSION_TAG> <RELEASE_COMMIT>" >&2
  exit 1
fi

if ! EXISTING_TAG_SHA=$(git rev-parse --verify "refs/tags/$VERSION^{commit}" 2>/dev/null); then
  echo "❌ Error: existing tag '$VERSION' does not resolve to a commit." >&2
  exit 1
fi

if ! RELEASE_SHA=$(git rev-parse --verify "$RELEASE_COMMIT^{commit}" 2>/dev/null); then
  echo "❌ Error: validated release commit '$RELEASE_COMMIT' cannot be resolved." >&2
  exit 1
fi

if [ "$EXISTING_TAG_SHA" != "$RELEASE_SHA" ]; then
  echo "❌ Error: tag $VERSION already points to $EXISTING_TAG_SHA, not the validated release commit $RELEASE_SHA." >&2
  exit 1
fi

echo "✅ Tag $VERSION already points to the validated release commit $RELEASE_SHA."

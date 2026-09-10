#!/bin/bash
# Usage: check-release-ancestry.sh <COMMIT> [MAIN_REF]
#
# Verifies that COMMIT is reachable from MAIN_REF (default: origin/main), i.e.
# that the commit has actually been merged into the release branch.
#
# The check is deliberately one-directional: a commit that is *ahead* of main
# (for example a feature-branch commit) must not be releasable, because the
# release workflow force-moves the floating vX and vX.Y tags that downstream
# repositories execute.
#
# Exit status: 0 when COMMIT is on MAIN_REF, 1 otherwise.

set -euo pipefail

COMMIT="${1:-}"
MAIN_REF="${2:-origin/main}"

if [ -z "$COMMIT" ]; then
  echo "Usage: check-release-ancestry.sh <COMMIT> [MAIN_REF]" >&2
  exit 1
fi

if ! COMMIT_SHA=$(git rev-parse --verify "${COMMIT}^{commit}" 2>/dev/null); then
  echo "❌ Error: could not resolve commit '$COMMIT'." >&2
  exit 1
fi

if ! MAIN_SHA=$(git rev-parse --verify "${MAIN_REF}^{commit}" 2>/dev/null); then
  echo "❌ Error: could not resolve release branch '$MAIN_REF'." >&2
  exit 1
fi

if ! git merge-base --is-ancestor "$COMMIT_SHA" "$MAIN_SHA"; then
  echo "❌ Error: commit $COMMIT_SHA is not reachable from '$MAIN_REF'." >&2
  echo "  Releases and floating tags must originate from the main branch." >&2
  echo "  Merge the commit into main and release from the merged commit." >&2
  exit 1
fi

echo "✅ Commit $COMMIT_SHA is on '$MAIN_REF'."

#!/bin/bash
set -euo pipefail

NEW_VERSION="${1:?Usage: check-release-progression.sh <NEW_VERSION> <VERSION_FORCE>}"
VERSION_FORCE="${2:-false}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERSION_FORCE_INPUT="$("$SCRIPT_DIR/normalize-action-input.sh" "$VERSION_FORCE")"
if [ "$VERSION_FORCE_INPUT" != "true" ] && [ "$VERSION_FORCE_INPUT" != "false" ]; then
  echo "Error: version_force must be 'true' or 'false', got: '${VERSION_FORCE}'" >&2
  exit 1
fi

if [ "$VERSION_FORCE_INPUT" = "true" ]; then
  echo "version_force is true; skipping version progression check."
  exit 0
fi

PREV_TAG="$(git tag --sort=version:refname \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | grep -vxF "v${NEW_VERSION}" \
  | tail -1 || true)"

if [ -z "$PREV_TAG" ]; then
  echo "No previous semver tag found; skipping version progression check."
  exit 0
fi

"$SCRIPT_DIR/check-version-progression.sh" "$NEW_VERSION" "${PREV_TAG#v}"

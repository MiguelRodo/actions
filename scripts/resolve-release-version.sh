#!/bin/bash
set -euo pipefail

RAW_VERSION="${1-}"
RAW_BUMP="${2-}"
FALLBACK_CURRENT="${3-0.0.0}"
ALLOW_TAG_REF="${4-false}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERSION_INPUT="$("$SCRIPT_DIR/normalize-action-input.sh" "$RAW_VERSION")"
BUMP_INPUT="$("$SCRIPT_DIR/normalize-action-input.sh" "$RAW_BUMP")"

if [ -n "$VERSION_INPUT" ] && [ -n "$BUMP_INPUT" ]; then
  echo "Error: cannot set both 'version' and 'bump_type'." >&2
  exit 1
fi

if [ -n "$BUMP_INPUT" ]; then
  PREV_TAG="$(git tag --sort=version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 || true)"
  CURRENT="${PREV_TAG#v}"
  CURRENT="${CURRENT:-$FALLBACK_CURRENT}"
  if [ -z "$CURRENT" ]; then
    echo "Error: could not determine a current version to bump." >&2
    exit 1
  fi
  VERSION="$("$SCRIPT_DIR/apply-version-bump.sh" "$BUMP_INPUT" "$CURRENT")"
elif [ -n "$VERSION_INPUT" ]; then
  VERSION="${VERSION_INPUT#v}"
elif [ "$ALLOW_TAG_REF" = "true" ] && [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  VERSION="$("$SCRIPT_DIR/normalize-action-input.sh" "${GITHUB_REF_NAME:-}")"
  VERSION="${VERSION#v}"
else
  echo "Error: could not resolve a release version from version, bump_type, or an allowed tag ref." >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version '$VERSION' is not valid semver (X.Y.Z)." >&2
  exit 1
fi

printf '%s\n' "$VERSION"

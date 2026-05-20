#!/bin/bash
# Usage: parse-semver-aliases.sh <TAG>
#
# Given a container image tag, prints the comma-separated list of SemVer alias
# tags to also push.
#
# Standard SemVer:         vX.Y.Z[...]       → "vX.Y,vX"
# Branch-prefixed SemVer:  {prefix}-vX.Y.Z[...] → "{prefix}-vX.Y,{prefix}-vX"
# Any other tag:           prints an empty string (not an error)
#
# Exit status: always 0.

set -euo pipefail

TAG="${1:?Usage: parse-semver-aliases.sh <TAG>}"
ALIAS_TAGS=""

SCRIPT_DIR=$(dirname "$0")
PARSED=$("$SCRIPT_DIR/parse-semver.sh" "$TAG")

if [ -n "$PARSED" ]; then
  IFS='|' read -r PREFIX MAJOR MINOR _ <<< "$PARSED"
  if [ -n "$PREFIX" ]; then
    ALIAS_TAGS="${PREFIX}-v${MAJOR}.${MINOR},${PREFIX}-v${MAJOR}"
  else
    ALIAS_TAGS="v${MAJOR}.${MINOR},v${MAJOR}"
  fi
fi

echo "$ALIAS_TAGS"

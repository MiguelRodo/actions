#!/bin/bash
# Usage: parse-semver.sh <TAG>
#
# Given a container image tag, parses the SemVer components and prints them in a structured format:
# "PREFIX|MAJOR|MINOR|PATCH"
# If there is no prefix, it will be empty: "|MAJOR|MINOR|PATCH"
# If the tag does not match a standard or branch-prefixed semver, the script prints an empty line.
#
# Standard SemVer:         vX.Y.Z[...]       → "|X|Y|Z"
# Branch-prefixed SemVer:  {prefix}-vX.Y.Z[...] → "{prefix}|X|Y|Z"
# Any other tag:           prints an empty string (not an error)
#
# Exit status: always 0.

set -euo pipefail

TAG="${1:?Usage: parse-semver.sh <TAG>}"

if [[ "$TAG" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  echo "|${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}"
elif [[ "$TAG" =~ ^(.+)-v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
else
  echo ""
fi

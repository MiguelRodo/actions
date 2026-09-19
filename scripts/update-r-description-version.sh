#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
description="${2:-DESCRIPTION}"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Error: version '$version' is not valid semver (X.Y.Z)." >&2
  exit 1
}
[[ -f "$description" ]] || {
  echo "Error: DESCRIPTION file not found: $description" >&2
  exit 1
}
grep -q '^Version:' "$description" || {
  echo "Error: DESCRIPTION has no Version field: $description" >&2
  exit 1
}
package="$(sed -n 's/^Package:[[:space:]]*//p' "$description" | head -n 1 | tr -d '[:space:]')"
[[ -n "$package" ]] || {
  echo "Error: DESCRIPTION has no Package field: $description" >&2
  exit 1
}

sed -i "s/^Version: .*/Version: ${version}/" "$description"
printf '%s_%s.tar.gz\n' "$package" "$version"

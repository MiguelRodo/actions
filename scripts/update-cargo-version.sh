#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
cargo_toml="${2:-Cargo.toml}"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Error: version '$version' is not valid semver (X.Y.Z)." >&2
  exit 1
}
[[ -f "$cargo_toml" ]] || {
  echo "Error: Cargo.toml file not found: $cargo_toml" >&2
  exit 1
}

package_version_line="$(awk '
  /^[[:space:]]*\[package\][[:space:]]*(#.*)?$/ { in_package = 1; next }
  /^[[:space:]]*\[/ { in_package = 0 }
  in_package && /^[[:space:]]*version[[:space:]]*=/ { print NR; exit }
' "$cargo_toml")"

[[ -n "$package_version_line" ]] || {
  echo "Error: no version field found in the [package] section of $cargo_toml." >&2
  exit 1
}

sed -i "${package_version_line}s/^[[:space:]]*version[[:space:]]*=.*$/version = \"${version}\"/" "$cargo_toml"

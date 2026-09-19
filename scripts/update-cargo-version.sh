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

sed -i "s/^version = \".*\"/version = \"${version}\"/" "$cargo_toml"

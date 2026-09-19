#!/usr/bin/env bash
set -euo pipefail

GLOBAL_VERSION_RAW="${1:-}"
PYTHON_VERSION_RAW="${2:-}"
R_VERSION_RAW="${3:-}"
BUMP_TYPE="${4:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GLOBAL_VERSION="$("$SCRIPT_DIR/normalize-action-input.sh" "$GLOBAL_VERSION_RAW")"
PYTHON_VERSION="$("$SCRIPT_DIR/normalize-action-input.sh" "$PYTHON_VERSION_RAW")"
R_VERSION="$("$SCRIPT_DIR/normalize-action-input.sh" "$R_VERSION_RAW")"
GLOBAL_VERSION="${GLOBAL_VERSION#v}"
PYTHON_VERSION="${PYTHON_VERSION#v}"
R_VERSION="${R_VERSION#v}"

resolve_package_version() {
  local override="$1"
  local current="$2"

  if [[ -n "$override" ]]; then
    printf '%s\n' "$override"
  elif [[ -n "$GLOBAL_VERSION" ]]; then
    printf '%s\n' "$GLOBAL_VERSION"
  else
    "$SCRIPT_DIR/apply-version-bump.sh" "$BUMP_TYPE" "$current"
  fi
}

if [[ -f pyproject.toml ]]; then
  CURRENT_PY="$(sed -n "s/^version = [\"']\([^\"']*\)[\"']/\1/p" pyproject.toml | tr -d '[:space:]')"
  [[ -n "$CURRENT_PY" ]] || {
    echo "Error: could not read version from pyproject.toml" >&2
    exit 1
  }

  NEW_PY_VERSION="$(resolve_package_version "$PYTHON_VERSION" "$CURRENT_PY")"
  sed -i "s/^version = \"[^\"]*\"/version = \"${NEW_PY_VERSION}\"/" pyproject.toml
  echo "Python version → ${NEW_PY_VERSION}"
else
  echo "No pyproject.toml found; skipping Python version update."
fi

if [[ -f DESCRIPTION ]]; then
  CURRENT_R="$(sed -n 's/^Version: \([0-9][0-9.]*\).*/\1/p' DESCRIPTION | tr -d '[:space:]')"
  [[ -n "$CURRENT_R" ]] || {
    echo "Error: could not read Version from DESCRIPTION" >&2
    exit 1
  }

  NEW_R_VERSION="$(resolve_package_version "$R_VERSION" "$CURRENT_R")"
  sed -i "s/^Version: .*/Version: ${NEW_R_VERSION}/" DESCRIPTION
  echo "R version → ${NEW_R_VERSION}"
else
  echo "No DESCRIPTION found; skipping R version update."
fi

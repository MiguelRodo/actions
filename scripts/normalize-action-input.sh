#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 1 ]] || {
  printf 'Usage: %s VALUE\n' "$0" >&2
  exit 1
}

printf '%s' "$1" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'

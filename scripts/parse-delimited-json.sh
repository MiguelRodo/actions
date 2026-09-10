#!/usr/bin/env bash
# Convert a comma/semicolon-delimited input into a JSON string array.
# Empty entries and surrounding whitespace are ignored; jq handles escaping.

set -euo pipefail

input="${1-}"
jq -cn --arg input "$input" '
  [$input | splits("[,;]")]
  | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
  | map(select(length > 0))
'

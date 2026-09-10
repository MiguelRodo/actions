#!/bin/bash
# Usage: check-required-ci.sh <REQUIRED_CHECK_NAME> [CHECK_RUNS_JSON]
#
# Validates that a required check run succeeded for the release commit before
# floating tags are moved. CHECK_RUNS_JSON is the payload returned by
# GET /repos/{owner}/{repo}/commits/{ref}/check-runs; when it is omitted or "-"
# the payload is read from stdin.
#
# Exit status: 0 when the required check exists and every run of it concluded
# successfully, 1 otherwise.

set -euo pipefail

REQUIRED_CHECK="${1:-}"
PAYLOAD_FILE="${2:--}"

if [ -z "$REQUIRED_CHECK" ]; then
  echo "Usage: check-required-ci.sh <REQUIRED_CHECK_NAME> [CHECK_RUNS_JSON]" >&2
  exit 1
fi

if [ "$PAYLOAD_FILE" = "-" ]; then
  PAYLOAD=$(cat)
else
  PAYLOAD=$(cat "$PAYLOAD_FILE")
fi

if ! echo "$PAYLOAD" | jq -e '.check_runs | type == "array"' >/dev/null 2>&1; then
  echo "❌ Error: could not read check runs for the release commit." >&2
  exit 1
fi

MATCHING=$(echo "$PAYLOAD" | jq --arg name "$REQUIRED_CHECK" '[.check_runs[] | select(.name == $name)]')

if [ "$(echo "$MATCHING" | jq 'length')" -eq 0 ]; then
  echo "❌ Error: required check '$REQUIRED_CHECK' has not run for the release commit." >&2
  echo "  Floating tags are only moved after required CI succeeds." >&2
  exit 1
fi

FAILED=$(echo "$MATCHING" | jq -r '[.[] | select(.status != "completed" or .conclusion != "success")] | length')

if [ "$FAILED" -ne 0 ]; then
  echo "❌ Error: required check '$REQUIRED_CHECK' did not succeed for the release commit." >&2
  echo "$MATCHING" | jq -r '.[] | "  - \(.name): status=\(.status) conclusion=\(.conclusion // "none")"' >&2
  exit 1
fi

echo "✅ Required check '$REQUIRED_CHECK' succeeded for the release commit."

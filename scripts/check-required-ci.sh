#!/bin/bash
# Usage: check-required-ci.sh <REQUIRED_CHECK_NAME> [REQUIRED_CHECK_NAME...]
#
# Validates that every required check run succeeded for the release commit
# before floating tags are moved. The check-runs payload is read from stdin;
# it is returned by GET /repos/{owner}/{repo}/commits/{ref}/check-runs.
#
# Exit status: 0 when every required check exists and every run of each check
# concluded successfully, 1 otherwise.

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: check-required-ci.sh <REQUIRED_CHECK_NAME> [REQUIRED_CHECK_NAME...]" >&2
  exit 1
fi

REQUIRED_CHECKS=("$@")
PAYLOAD=$(cat)

if ! echo "$PAYLOAD" | jq -e '.check_runs | type == "array"' >/dev/null 2>&1; then
  echo "❌ Error: could not read check runs for the release commit." >&2
  exit 1
fi

for REQUIRED_CHECK in "${REQUIRED_CHECKS[@]}"; do
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
done

#!/usr/bin/env bash

set -euo pipefail

GH_BIN="${GH_BIN:-gh}"
DRY_RUN="${SENTINEL_DEDUP_DRY_RUN:-false}"
MARKER_PATTERN='sentinel-fingerprint:v(1|2):[^[:space:]<>]+'

usage() {
  cat <<'EOF'
Usage:
  sentinel-fingerprint.sh fingerprint REPOSITORY PATH CLASS SCOPE < vulnerable-hunk
  sentinel-fingerprint.sh deduplicate REPOSITORY PR_NUMBER
  sentinel-fingerprint.sh sweep REPOSITORY

The fingerprint command hashes the exact vulnerable hunk from standard input.
The deduplicate and sweep commands require gh authentication with pull-request write access.
Set SENTINEL_DEDUP_DRY_RUN=true to report duplicates without closing them.
EOF
}

validate_component() {
  local name="$1"
  local value="$2"
  local pattern="$3"

  if [[ ! "$value" =~ $pattern ]]; then
    echo "Invalid $name: $value" >&2
    exit 2
  fi
}

create_fingerprint() {
  local repository="$1"
  local path="$2"
  local vulnerability_class="$3"
  local scope="$4"
  local input_file
  local hunk_hash

  validate_component repository "$repository" '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
  validate_component path "$path" '^[A-Za-z0-9_./-]+$'
  validate_component class "$vulnerability_class" '^[a-z0-9][a-z0-9._-]*$'
  validate_component scope "$scope" '^[a-z0-9][a-z0-9._-]*$'

  input_file=$(mktemp)
  cat > "$input_file"
  if [[ ! -s "$input_file" ]]; then
    rm -f "$input_file"
    echo "The vulnerable hunk on standard input must not be empty." >&2
    exit 2
  fi

  hunk_hash=$(sha256sum "$input_file" | awk '{print $1}')
  rm -f "$input_file"
  printf '<!-- sentinel-fingerprint:v2:%s:%s:%s:%s:sha256:%s -->\n' \
    "$repository" "$path" "$vulnerability_class" "$scope" "$hunk_hash"
}

extract_fingerprint() {
  local body="$1"
  local fingerprints

  fingerprints=$(grep -oE "$MARKER_PATTERN" <<< "$body" | sort -u || true)
  if [[ -z "$fingerprints" ]]; then
    return 1
  fi
  if [[ $(wc -l <<< "$fingerprints") -ne 1 ]]; then
    echo "Sentinel remediation PRs must contain exactly one unique fingerprint." >&2
    return 2
  fi
  printf '%s\n' "$fingerprints"
}

close_duplicate() {
  local repository="$1"
  local duplicate_number="$2"
  local canonical_number="$3"
  local fingerprint="$4"
  local message

  message="Superseded duplicate Sentinel remediation for \`$fingerprint\`. The canonical open remediation is #$canonical_number."
  if [[ "$DRY_RUN" == "true" ]]; then
    printf 'Would close #%s as a duplicate of #%s (%s)\n' \
      "$duplicate_number" "$canonical_number" "$fingerprint"
    return
  fi

  "$GH_BIN" pr comment "$duplicate_number" --repo "$repository" --body "$message" >/dev/null
  "$GH_BIN" pr close "$duplicate_number" --repo "$repository" --delete-branch=false >/dev/null
  printf 'Closed #%s as a duplicate of #%s (%s)\n' \
    "$duplicate_number" "$canonical_number" "$fingerprint"
}

deduplicate_pr() {
  local repository="$1"
  local pr_number="$2"
  local owner
  local pr_json
  local author
  local body
  local fingerprint
  local open_prs
  local matches
  local canonical_number

  validate_component repository "$repository" '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
  validate_component PR_NUMBER "$pr_number" '^[0-9]+$'

  owner=$("$GH_BIN" api "repos/$repository" --jq '.owner.login')
  pr_json=$("$GH_BIN" pr view "$pr_number" --repo "$repository" \
    --json number,title,body,state,author,url)
  author=$(jq -r '.author.login' <<< "$pr_json")
  body=$(jq -r '.body // ""' <<< "$pr_json")

  if [[ "$author" != "$owner" ]]; then
    printf 'Skipping #%s: author %s is not repository owner %s.\n' \
      "$pr_number" "$author" "$owner"
    return
  fi
  if ! fingerprint=$(extract_fingerprint "$body"); then
    printf 'Skipping #%s: no single Sentinel fingerprint found.\n' "$pr_number"
    return
  fi

  open_prs=$("$GH_BIN" pr list --repo "$repository" --state open --limit 1000 \
    --json number,title,body,author,url)
  matches=$(jq --arg fingerprint "$fingerprint" --arg owner "$owner" '
    [.[]
      | select(.author.login == $owner)
      | select((.body // "") | contains($fingerprint))]
    | sort_by(.number)
  ' <<< "$open_prs")
  canonical_number=$(jq -r '.[0].number // empty' <<< "$matches")

  if [[ -z "$canonical_number" ]]; then
    echo "No open PR found for fingerprint $fingerprint." >&2
    exit 1
  fi
  if [[ "$canonical_number" == "$pr_number" ]]; then
    printf '#%s is the canonical open remediation for %s.\n' \
      "$pr_number" "$fingerprint"
    return
  fi

  close_duplicate "$repository" "$pr_number" "$canonical_number" "$fingerprint"
}

sweep_repository() {
  local repository="$1"
  local owner
  local open_prs
  local pr_number

  validate_component repository "$repository" '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
  owner=$("$GH_BIN" api "repos/$repository" --jq '.owner.login')
  open_prs=$("$GH_BIN" pr list --repo "$repository" --state open --limit 1000 \
    --json number,title,body,author,url)

  while IFS= read -r pr_number; do
    deduplicate_pr "$repository" "$pr_number"
  done < <(jq -r --arg owner "$owner" '
    .[]
    | select(.author.login == $owner)
    | select((.body // "") | contains("sentinel-fingerprint:"))
    | .number
  ' <<< "$open_prs")
}

main() {
  local command="${1:-}"

  case "$command" in
    fingerprint)
      [[ $# -eq 5 ]] || { usage >&2; exit 2; }
      create_fingerprint "$2" "$3" "$4" "$5"
      ;;
    deduplicate)
      [[ $# -eq 3 ]] || { usage >&2; exit 2; }
      deduplicate_pr "$2" "$3"
      ;;
    sweep)
      [[ $# -eq 2 ]] || { usage >&2; exit 2; }
      sweep_repository "$2"
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

readonly PROJECT_ITEMS_QUERY="query(\$projectId: ID!, \$after: String) { node(id: \$projectId) { ... on ProjectV2 { items(first: 100, after: \$after) { pageInfo { hasNextPage endCursor } nodes { content { __typename ... on Issue { id } } } } } } }"
readonly ADD_ISSUE_MUTATION="mutation(\$projectId: ID!, \$contentId: ID!) { addProjectV2ItemById(input: {projectId: \$projectId, contentId: \$contentId}) { item { id } } }"

declare -A existing_issue_ids=()

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

resolve_inputs() {
  if [[ -z "${SOURCE_REPO_NAME:-}" ]]; then
    SOURCE_REPO_NAME="$(basename "$(pwd)")"
  fi

  if [[ -z "${PROJECT_NAME:-}" ]]; then
    PROJECT_NAME="$SOURCE_REPO_NAME"
  fi

  if [[ -z "${SOURCE_REPO_OWNER:-}" ]]; then
    SOURCE_REPO_OWNER="${CURRENT_USER:-}"
  fi

  if [[ -z "${PROJECT_OWNER:-}" ]]; then
    PROJECT_OWNER="$SOURCE_REPO_OWNER"
  fi

  SOURCE_REPO="${SOURCE_REPO_OWNER}/${SOURCE_REPO_NAME}"
}

validate_source_repo() {
  if [[ ! "$SOURCE_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    die "Invalid source repository format. Expected format: owner/repo."
  fi
}

ensure_owner_exists() {
  if [[ "${IS_PROJECT_OWNER_ORG:-false}" == "true" ]]; then
    gh api "orgs/${PROJECT_OWNER}" >/dev/null || die "Organization '${PROJECT_OWNER}' not found."
  else
    gh api "users/${PROJECT_OWNER}" >/dev/null || die "User '${PROJECT_OWNER}' not found."
  fi
}

ensure_repo_exists() {
  gh api "repos/${SOURCE_REPO}" >/dev/null || die "Repository '${SOURCE_REPO}' not found."
}

get_project_id() {
  local project_list project_ids project_count

  if [[ "${IS_PROJECT_OWNER_ORG:-false}" == "true" ]]; then
    project_list="$(gh projects list --org "${PROJECT_OWNER}" --format json)" || die "Could not obtain project list."
  else
    project_list="$(gh projects list --user "${PROJECT_OWNER}" --format json)" || die "Could not obtain project list."
  fi

  project_ids="$(jq -c --arg title "${PROJECT_NAME}" \
    '[.projects[] | select(.title == $title) | .id]' <<<"$project_list")" || {
    die "Could not extract project ID."
  }
  project_count="$(jq -r 'length' <<<"$project_ids")"

  if [[ "$project_count" -eq 0 ]]; then
    die "Project ID not found for project '${PROJECT_NAME}' owned by '${PROJECT_OWNER}'."
  fi
  if [[ "$project_count" -ne 1 ]]; then
    die "Multiple projects named '${PROJECT_NAME}' found for owner '${PROJECT_OWNER}'."
  fi

  PROJECT_ID="$(jq -r '.[0]' <<<"$project_ids")"
}

fetch_existing_issue_ids() {
  local has_next_page="true"
  local end_cursor=""
  local response

  while [[ "$has_next_page" == "true" ]]; do
    if ! response="$(gh api graphql \
      -f query="$PROJECT_ITEMS_QUERY" \
      -f projectId="$PROJECT_ID" \
      -f after="$end_cursor")"; then
      die "Could not fetch existing project items."
    fi

    if ! jq -e '
      type == "object" and
      ((.errors // []) | length == 0) and
      (.data.node.items.nodes | type == "array") and
      (.data.node.items.pageInfo.hasNextPage | type == "boolean") and
      (
        .data.node.items.pageInfo.endCursor == null or
        (.data.node.items.pageInfo.endCursor | type == "string")
      )
    ' <<<"$response" >/dev/null; then
      die "Project items response was invalid or contained GraphQL errors."
    fi

    while IFS= read -r content_json; do
      local issue_id
      issue_id="$(jq -r '.id' <<<"$content_json")"
      existing_issue_ids["$issue_id"]=1
    done < <(jq -c '
      .data.node.items.nodes[] |
      .content |
      select(
        . != null and
        .__typename == "Issue" and
        (.id | type == "string" and length > 0)
      ) |
      {id}
    ' <<<"$response")

    has_next_page="$(jq -r '.data.node.items.pageInfo.hasNextPage' <<<"$response")"
    end_cursor="$(jq -r '.data.node.items.pageInfo.endCursor' <<<"$response")"
    if [[ "$end_cursor" == "null" ]]; then
      end_cursor=""
    fi
    if [[ "$has_next_page" == "true" && -z "$end_cursor" ]]; then
      die "Project items response indicated another page without an end cursor."
    fi
  done
}

get_source_issues() {
  if ! ISSUES_JSON="$(gh issue list --repo "${SOURCE_REPO}" --limit 9999 --json number,id)"; then
    die "Could not obtain issues from repository '${SOURCE_REPO}'."
  fi

  if ! jq -e '
    type == "array" and
    all(.[];
      (.number | type == "number") and
      (.id | type == "string" and length > 0)
    )
  ' <<<"$ISSUES_JSON" >/dev/null; then
    die "Issue list response was invalid."
  fi
}

sync_issues() {
  local issues_added=0

  while IFS= read -r issue_json; do
    local issue_number issue_node_id
    issue_number="$(jq -r '.number' <<<"$issue_json")"
    issue_node_id="$(jq -r '.id' <<<"$issue_json")"

    if [[ -n "${existing_issue_ids["$issue_node_id"]+x}" ]]; then
      printf 'Issue #%s is already in the project. Skipping.\n' "$issue_number"
    else
      local mutation_response
      if ! mutation_response="$(gh api graphql \
        -f query="$ADD_ISSUE_MUTATION" \
        -f projectId="$PROJECT_ID" \
        -f contentId="$issue_node_id")"; then
        die "Failed to add issue #${issue_number} to the project."
      fi
      if ! jq -e '
        type == "object" and
        ((.errors // []) | length == 0) and
        (.data.addProjectV2ItemById.item.id | type == "string" and length > 0)
      ' <<<"$mutation_response" >/dev/null; then
        die "Project mutation for issue #${issue_number} returned errors or no item."
      fi

      printf 'Added issue #%s to the project.\n' "$issue_number"
      issues_added=$((issues_added + 1))
    fi
  done < <(jq -c '.[] | {number, id}' <<<"$ISSUES_JSON")

  printf 'issues_added=%s\n' "$issues_added" >> "$GITHUB_OUTPUT"
}

main() {
  : "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"
  : "${CURRENT_USER:=}"

  resolve_inputs
  validate_source_repo
  ensure_owner_exists
  ensure_repo_exists
  get_project_id
  get_source_issues

  if [[ -z "$ISSUES_JSON" || "$ISSUES_JSON" == "[]" ]]; then
    printf 'issues_added=0\n' >> "$GITHUB_OUTPUT"
    printf 'No issues found in repository %s.\n' "$SOURCE_REPO"
    return 0
  fi

  fetch_existing_issue_ids
  sync_issues
}

main "$@"

#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/add-issues-to-project.sh"
ACTION_FILE="$ROOT_DIR/add-issues-to-project/action.yml"

setup() {
  REPO_DIR="$BATS_TEST_TMPDIR/repo"
  FAKE_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$REPO_DIR" "$FAKE_BIN"

  cd "$REPO_DIR" || return 1
  git init --quiet --initial-branch=main .
  git config user.email "test@example.com"
  git config user.name "Test User"
  printf 'repo\n' > README.md
  git add README.md
  git commit --quiet -m "Initial commit"

  export GH_CALL_LOG="$BATS_TEST_TMPDIR/gh.log"
  export GH_GRAPHQL_PAGE_COUNT_FILE="$BATS_TEST_TMPDIR/graphql-page-count"
  export GH_GRAPHQL_MUTATION_COUNT_FILE="$BATS_TEST_TMPDIR/graphql-mutation-count"
  export GH_GRAPHQL_PAGE_DIR="$BATS_TEST_TMPDIR"
  export GH_PROJECTS_FILE="$BATS_TEST_TMPDIR/projects.json"
  export GH_ISSUES_FILE="$BATS_TEST_TMPDIR/issues.json"
  export GITHUB_OUTPUT_FILE="$BATS_TEST_TMPDIR/github-output"
  : > "$GH_CALL_LOG"
  printf '0' > "$GH_GRAPHQL_PAGE_COUNT_FILE"
  printf '0' > "$GH_GRAPHQL_MUTATION_COUNT_FILE"
  printf '{"projects":[]}\n' > "$GH_PROJECTS_FILE"
  printf '[]\n' > "$GH_ISSUES_FILE"
  : > "$GITHUB_OUTPUT_FILE"

  cat > "$FAKE_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%q ' "$@" >> "$GH_CALL_LOG"
printf '\n' >> "$GH_CALL_LOG"

case "${1:-}" in
  --version)
    printf 'gh version 2.0.0 (mock)\n'
    exit 0
    ;;
  extension)
    if [[ "${2:-}" == "install" ]]; then
      exit 0
    fi
    ;;
  api)
    case "${2:-}" in
      orgs/*)
        if [[ -n "${GH_FAIL_ORG_LOOKUP:-}" ]]; then
          printf 'org lookup failed\n' >&2
          exit 1
        fi
        exit 0
        ;;
      users/*)
        if [[ -n "${GH_FAIL_USER_LOOKUP:-}" ]]; then
          printf 'user lookup failed\n' >&2
          exit 1
        fi
        exit 0
        ;;
      repos/*)
        if [[ -n "${GH_FAIL_REPO_LOOKUP:-}" ]]; then
          printf 'repo lookup failed\n' >&2
          exit 1
        fi
        exit 0
        ;;
      graphql)
        if [[ "$*" == *addProjectV2ItemById* ]]; then
          printf '%s' "$(( $(<"$GH_GRAPHQL_MUTATION_COUNT_FILE") + 1 ))" > "$GH_GRAPHQL_MUTATION_COUNT_FILE"
          if [[ -n "${GH_FAIL_GRAPHQL_MUTATION:-}" ]]; then
            printf 'mutation failed\n' >&2
            exit 1
          fi
          if [[ -n "${GH_GRAPHQL_MUTATION_ERROR_RESPONSE:-}" ]]; then
            printf '{"data":{"addProjectV2ItemById":null},"errors":[{"message":"permission denied"}]}\n'
            exit 0
          fi
          printf '{"data":{"addProjectV2ItemById":{"item":{"id":"mock-item-id"}}}}\n'
          exit 0
        fi

        printf '%s' "$(( $(<"$GH_GRAPHQL_PAGE_COUNT_FILE") + 1 ))" > "$GH_GRAPHQL_PAGE_COUNT_FILE"
        page_count="$(<"$GH_GRAPHQL_PAGE_COUNT_FILE")"
        if [[ -n "${GH_FAIL_GRAPHQL_PAGE_ON:-}" && "$page_count" == "$GH_FAIL_GRAPHQL_PAGE_ON" ]]; then
          printf 'page failed\n' >&2
          exit 1
        fi

        response_file="$GH_GRAPHQL_PAGE_DIR/graphql-page-$page_count.json"
        if [[ -f "$response_file" ]]; then
          cat "$response_file"
        else
          printf '{"data":{"node":{"items":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}}}}\n'
        fi
        exit 0
        ;;
    esac
    ;;
  projects)
    if [[ "${2:-}" == "list" ]]; then
      if [[ -n "${GH_FAIL_PROJECTS_LIST:-}" ]]; then
        printf 'projects list failed\n' >&2
        exit 1
      fi
      if [[ -f "$GH_PROJECTS_FILE" ]]; then
        cat "$GH_PROJECTS_FILE"
      else
        printf '{"projects":[]}\n'
      fi
      exit 0
    fi
    ;;
  issue)
    if [[ "${2:-}" == "list" ]]; then
      if [[ -n "${GH_FAIL_ISSUE_LIST:-}" ]]; then
        printf 'issue list failed\n' >&2
        exit 1
      fi
      if [[ -f "$GH_ISSUES_FILE" ]]; then
        cat "$GH_ISSUES_FILE"
      else
        printf '[]\n'
      fi
      exit 0
    fi
    ;;
esac

printf 'Unhandled gh invocation: %s\n' "$*" >&2
exit 1
EOF

  chmod +x "$FAKE_BIN/gh"
  chmod +x "$SCRIPT"
  export PATH="$FAKE_BIN:$PATH"

  export CURRENT_USER="test-user"
  export PROJECT_NAME="test-project"
  export PROJECT_OWNER="octo-org"
  export SOURCE_REPO_NAME="test-repo"
  export SOURCE_REPO_OWNER="octo-org"
  export IS_PROJECT_OWNER_ORG="true"
  export GH_TOKEN="mock-token"
}

write_projects_json() {
  python3 - "$GH_PROJECTS_FILE" "$1" "$2" "$3" <<'PY'
import json
import sys

path = sys.argv[1]
title = sys.argv[2]
project_id = sys.argv[3]

with open(path, "w", encoding="utf-8") as fh:
    json.dump({"projects": [{"title": title, "id": project_id}]}, fh)
PY
}

write_issues_json() {
  python3 - "$GH_ISSUES_FILE" "$@" <<'PY'
import json
import sys

path = sys.argv[1]
args = sys.argv[2:]

if len(args) % 2 != 0:
    raise SystemExit("expected number/id pairs")

issues = []
for index in range(0, len(args), 2):
    issues.append({"number": int(args[index]), "id": args[index + 1]})

with open(path, "w", encoding="utf-8") as fh:
    json.dump(issues, fh)
PY
}

write_graphql_pages() {
  cat > "$GH_GRAPHQL_PAGE_DIR/graphql-page-1.json" <<'JSON'
{"data":{"node":{"items":{"pageInfo":{"hasNextPage":true,"endCursor":"cursor-1"},"nodes":[{"content":{"__typename":"Issue","id":"existing-1"}},{"content":{"__typename":"Issue","id":"existing-2"}}]}}}}
JSON
  cat > "$GH_GRAPHQL_PAGE_DIR/graphql-page-2.json" <<'JSON'
{"data":{"node":{"items":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[{"content":{"__typename":"PullRequest","id":"pr-1"}},{"content":{"__typename":"Issue","id":"existing-3"}}]}}}}
JSON
}

run_sync_script() {
  run env \
    PATH="$PATH" \
    GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE" \
    GH_TOKEN="$GH_TOKEN" \
    CURRENT_USER="$CURRENT_USER" \
    PROJECT_NAME="$PROJECT_NAME" \
    PROJECT_OWNER="$PROJECT_OWNER" \
    IS_PROJECT_OWNER_ORG="$IS_PROJECT_OWNER_ORG" \
    SOURCE_REPO_NAME="$SOURCE_REPO_NAME" \
    SOURCE_REPO_OWNER="$SOURCE_REPO_OWNER" \
    "$SCRIPT"
}

@test "action wiring calls the helper script and exposes issues_added" {
  run grep -F 'run: "$GITHUB_ACTION_PATH/../scripts/add-issues-to-project.sh"' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'value: ${{ steps.add-issues.outputs.issues_added }}' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "syncs issues across paginated project pages and preserves adversarial issue ids" {
  write_projects_json "test-project" "project-123"
  write_graphql_pages
  export PROJECT_NAME="test-project"
  export PROJECT_OWNER="octo-org"
  export SOURCE_REPO_NAME="test-repo"
  export SOURCE_REPO_OWNER="octo-org"
  export IS_PROJECT_OWNER_ORG="true"

  weird_issue_id=$'adversarial id "quote" \'apostrophe\' \\backslash; $(echo safe) [json] {"k":"v"}\nsecond-line'
  write_issues_json \
    1 "existing-1" \
    2 "$weird_issue_id" \
    3 "existing-3"

  run_sync_script

  [ "$status" -eq 0 ]
  [ "$(grep -c 'Added issue #' <<<"$output")" -eq 1 ]
  [[ "$output" == *"Issue #1 is already in the project. Skipping."* ]]
  [[ "$output" == *"Issue #3 is already in the project. Skipping."* ]]
  [[ "$output" == *"Added issue #2 to the project."* ]]
  [ "$(cat "$GH_GRAPHQL_PAGE_COUNT_FILE")" -eq 2 ]
  [ "$(cat "$GH_GRAPHQL_MUTATION_COUNT_FILE")" -eq 1 ]
  [[ "$(cat "$GITHUB_OUTPUT_FILE")" == "issues_added=1" ]]
}

@test "fails when the owner lookup API returns an error" {
  export PROJECT_OWNER="test-user"
  export SOURCE_REPO_OWNER="test-user"
  export IS_PROJECT_OWNER_ORG="false"
  export GH_FAIL_USER_LOOKUP=1

  run_sync_script

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: User 'test-user' not found."* ]]
  [[ "$(cat "$GH_CALL_LOG")" == *"api users/test-user"* ]]
  [[ "$(cat "$GH_CALL_LOG")" != *"repos/test-user/test-repo"* ]]
}

@test "fails when the project list API returns an error" {
  export PROJECT_OWNER="octo-org"
  export SOURCE_REPO_OWNER="octo-org"
  export IS_PROJECT_OWNER_ORG="true"
  export GH_FAIL_PROJECTS_LIST=1

  run_sync_script

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Could not obtain project list."* ]]
  [ "$(cat "$GH_GRAPHQL_PAGE_COUNT_FILE")" -eq 0 ]
  [ "$(cat "$GH_GRAPHQL_MUTATION_COUNT_FILE")" -eq 0 ]
}

@test "fails rather than choosing arbitrarily when duplicate project titles are returned" {
  cat > "$GH_PROJECTS_FILE" <<'JSON'
{"projects":[{"title":"test-project","id":"project-1"},{"title":"test-project","id":"project-2"}]}
JSON

  run_sync_script

  [ "$status" -eq 1 ]
  [[ "$output" == *"Multiple projects named 'test-project'"* ]]
  [ "$(cat "$GH_GRAPHQL_PAGE_COUNT_FILE")" -eq 0 ]
}

@test "returns zero without querying project items when the source repository is empty" {
  write_projects_json "test-project" "project-123"

  run_sync_script

  [ "$status" -eq 0 ]
  [[ "$output" == *"No issues found in repository octo-org/test-repo."* ]]
  [[ "$(cat "$GITHUB_OUTPUT_FILE")" == "issues_added=0" ]]
  [ "$(cat "$GH_GRAPHQL_PAGE_COUNT_FILE")" -eq 0 ]
  [ "$(cat "$GH_GRAPHQL_MUTATION_COUNT_FILE")" -eq 0 ]
}

@test "fails when issue listing returns an error" {
  write_projects_json "test-project" "project-123"
  export GH_FAIL_ISSUE_LIST=1

  run_sync_script

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Could not obtain issues from repository 'octo-org/test-repo'."* ]]
  [ "$(cat "$GH_GRAPHQL_PAGE_COUNT_FILE")" -eq 0 ]
  [ "$(cat "$GH_GRAPHQL_MUTATION_COUNT_FILE")" -eq 0 ]
}

@test "fails when GraphQL pagination cannot fetch the next project page" {
  write_projects_json "test-project" "project-123"
  cat > "$GH_GRAPHQL_PAGE_DIR/graphql-page-1.json" <<'JSON'
{"data":{"node":{"items":{"pageInfo":{"hasNextPage":true,"endCursor":"cursor-1"},"nodes":[{"content":{"__typename":"Issue","id":"existing-1"}}]}}}}
JSON
  export GH_FAIL_GRAPHQL_PAGE_ON=2

  run_sync_script

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Could not fetch existing project items."* ]]
  [ "$(cat "$GH_GRAPHQL_PAGE_COUNT_FILE")" -eq 2 ]
  [ "$(cat "$GH_GRAPHQL_MUTATION_COUNT_FILE")" -eq 0 ]
}

@test "fails on a success-shaped GraphQL response containing provider errors" {
  write_projects_json "test-project" "project-123"
  cat > "$GH_GRAPHQL_PAGE_DIR/graphql-page-1.json" <<'JSON'
{"data":{"node":null},"errors":[{"message":"permission denied"}]}
JSON

  run_sync_script

  [ "$status" -eq 1 ]
  [[ "$output" == *"GraphQL errors"* ]]
  [ "$(cat "$GH_GRAPHQL_MUTATION_COUNT_FILE")" -eq 0 ]
}

@test "fails when pagination claims another page without a cursor" {
  write_projects_json "test-project" "project-123"
  cat > "$GH_GRAPHQL_PAGE_DIR/graphql-page-1.json" <<'JSON'
{"data":{"node":{"items":{"pageInfo":{"hasNextPage":true,"endCursor":null},"nodes":[]}}}}
JSON

  run_sync_script

  [ "$status" -eq 1 ]
  [[ "$output" == *"without an end cursor"* ]]
  [ "$(cat "$GH_GRAPHQL_PAGE_COUNT_FILE")" -eq 1 ]
}

@test "fails when adding an issue to the project returns an error" {
  write_projects_json "test-project" "project-123"
  cat > "$GH_GRAPHQL_PAGE_DIR/graphql-page-1.json" <<'JSON'
{"data":{"node":{"items":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}}}}
JSON
  write_issues_json 1 "new-issue"
  export GH_FAIL_GRAPHQL_MUTATION=1

  run_sync_script

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Failed to add issue #1 to the project."* ]]
  [ "$(cat "$GH_GRAPHQL_PAGE_COUNT_FILE")" -eq 1 ]
  [ "$(cat "$GH_GRAPHQL_MUTATION_COUNT_FILE")" -eq 1 ]
}

@test "fails when a project mutation exits successfully but returns GraphQL errors" {
  write_projects_json "test-project" "project-123"
  cat > "$GH_GRAPHQL_PAGE_DIR/graphql-page-1.json" <<'JSON'
{"data":{"node":{"items":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}}}}
JSON
  write_issues_json 1 "new-issue"
  export GH_GRAPHQL_MUTATION_ERROR_RESPONSE=1

  run_sync_script

  [ "$status" -eq 1 ]
  [[ "$output" == *"returned errors or no item"* ]]
  [ "$(cat "$GH_GRAPHQL_MUTATION_COUNT_FILE")" -eq 1 ]
  [ ! -s "$GITHUB_OUTPUT_FILE" ]
}

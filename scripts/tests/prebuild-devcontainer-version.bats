#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/prebuild-devcontainer-version.sh"
ACTION_FILE="$ROOT_DIR/prebuild-devcontainer/action.yml"

setup() {
  export MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  export MOCK_SKOPEO_LOG="$BATS_TEST_TMPDIR/skopeo.log"
  export MOCK_CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
  mkdir -p "$MOCK_BIN"
  : > "$MOCK_SKOPEO_LOG"
  : > "$MOCK_CURL_LOG"
}

write_skopeo_mock() {
  cat > "$MOCK_BIN/skopeo" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_SKOPEO_LOG"
cat "$MOCK_SKOPEO_RESPONSE"
MOCK
  chmod +x "$MOCK_BIN/skopeo"
}

@test "non-GHCR bump and cache decisions share one registry read" {
  response="$BATS_TEST_TMPDIR/skopeo.json"
  printf '%s\n' '{"Tags":["latest","v1.2.3","v1.2","v1","other"]}' > "$response"
  export MOCK_SKOPEO_RESPONSE="$response"
  write_skopeo_mock

  run bash -c 'PATH="$1:$PATH" "$2" registry.example/repo "" patch false refs/heads/main 2>"$3"' \
    _ "$MOCK_BIN" "$SCRIPT" "$BATS_TEST_TMPDIR/stderr"
  [ "$status" -eq 0 ]
  run jq -e '.image_tag == "v1.2.4" and .cache_from == "registry.example/repo:latest"' <<<"$output"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$MOCK_SKOPEO_LOG")" -eq 1 ]
}

@test "version progression uses the snapshot and version_force remains the escape hatch" {
  response="$BATS_TEST_TMPDIR/skopeo.json"
  printf '%s\n' '{"Tags":["v1.2.3"]}' > "$response"
  export MOCK_SKOPEO_RESPONSE="$response"
  write_skopeo_mock

  run bash -c 'PATH="$1:$PATH" "$2" registry.example/repo v1.2.5 "" false refs/heads/main 2>/dev/null' \
    _ "$MOCK_BIN" "$SCRIPT"
  [ "$status" -ne 0 ]

  run bash -c 'PATH="$1:$PATH" "$2" registry.example/repo v1.2.5 "" true refs/heads/main 2>/dev/null' \
    _ "$MOCK_BIN" "$SCRIPT"
  [ "$status" -eq 0 ]
  run jq -e '.image_tag == "v1.2.5" and .cache_from == "registry.example/repo:v1.2.3"' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "GHCR keeps org-to-user fallback without a second decision-time fetch" {
  cat > "$MOCK_BIN/curl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_CURL_LOG"
if [[ "$*" == *'/orgs/octo/'* ]]; then
  printf '[]\n'
else
  printf '%s\n' '[{"metadata":{"container":{"tags":["latest","v2.0.0"]}}},{"metadata":{"container":{"tags":["v1.9.9"]}}}]'
fi
MOCK
  chmod +x "$MOCK_BIN/curl"

  run bash -c 'PATH="$1:$PATH" INPUT_GITHUB_TOKEN=token "$2" ghcr.io/octo/pkg "" patch false refs/heads/main 2>/dev/null' \
    _ "$MOCK_BIN" "$SCRIPT"
  [ "$status" -eq 0 ]
  run jq -e '.image_tag == "v2.0.1" and .cache_from == "ghcr.io/octo/pkg:latest"' <<<"$output"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$MOCK_CURL_LOG")" -eq 2 ]
  grep -q '/orgs/octo/packages/container/pkg/versions' "$MOCK_CURL_LOG"
  grep -q '/user/packages/container/pkg/versions' "$MOCK_CURL_LOG"
}

@test "git tag trigger remains a version source" {
  response="$BATS_TEST_TMPDIR/skopeo.json"
  printf '%s\n' '{"Tags":[]}' > "$response"
  export MOCK_SKOPEO_RESPONSE="$response"
  write_skopeo_mock

  run bash -c 'PATH="$1:$PATH" "$2" registry.example/repo "" "" false refs/tags/v3.0.0 2>/dev/null' \
    _ "$MOCK_BIN" "$SCRIPT"
  [ "$status" -eq 0 ]
  run jq -e '.image_tag == "v3.0.0"' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "composite action delegates registry and version decisions to one helper" {
  [ "$(grep -c 'scripts/prebuild-devcontainer-version.sh' "$ACTION_FILE")" -eq 1 ]
  ! grep -Eq '(^|[^[:alnum:]_])(curl|skopeo)([^[:alnum:]_]|$)' "$ACTION_FILE"
}

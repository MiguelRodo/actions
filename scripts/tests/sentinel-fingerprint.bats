#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/sentinel-fingerprint.sh"

setup() {
  export MOCK_LOG="$BATS_TEST_TMPDIR/gh.log"
  export GH_BIN="$BATS_TEST_TMPDIR/gh"
  cat > "$GH_BIN" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_LOG"

case "$1 $2" in
  "api repos/MiguelRodo/actions")
    printf 'MiguelRodo\n'
    ;;
  "pr view")
    number="$3"
    if [[ "$number" == "10" || "$number" == "11" ]]; then
      jq -n --argjson number "$number" '{
        number: $number,
        title: "🛡️ Sentinel: test finding",
        body: "<!-- sentinel-fingerprint:v2:MiguelRodo/actions:path/action.yml:code-injection:step:sha256:abc -->",
        state: "OPEN",
        author: {login: "MiguelRodo"},
        url: ("https://example.test/pull/" + ($number | tostring))
      }'
    else
      jq -n --argjson number "$number" '{
        number: $number,
        title: "External PR",
        body: "<!-- sentinel-fingerprint:v2:MiguelRodo/actions:path/action.yml:code-injection:step:sha256:abc -->",
        state: "OPEN",
        author: {login: "contributor"},
        url: ("https://example.test/pull/" + ($number | tostring))
      }'
    fi
    ;;
  "pr list")
    cat <<'JSON'
[
  {"number":10,"title":"Sentinel A","body":"<!-- sentinel-fingerprint:v2:MiguelRodo/actions:path/action.yml:code-injection:step:sha256:abc -->","author":{"login":"MiguelRodo"},"url":"https://example.test/pull/10"},
  {"number":11,"title":"Sentinel B","body":"<!-- sentinel-fingerprint:v2:MiguelRodo/actions:path/action.yml:code-injection:step:sha256:abc -->","author":{"login":"MiguelRodo"},"url":"https://example.test/pull/11"}
]
JSON
    ;;
  "pr comment"|"pr close")
    ;;
  *)
    echo "Unexpected gh invocation: $*" >&2
    exit 1
    ;;
esac
MOCK
  chmod +x "$GH_BIN"
}

@test "unchanged vulnerable hunks produce the same fingerprint" {
  run bash -c 'printf %s "const file = unsafe;" | "$1" fingerprint MiguelRodo/actions prebuild-devcontainer/action.yml code-injection inject-build-info' _ "$SCRIPT"
  [ "$status" -eq 0 ]
  first="$output"

  run bash -c 'printf %s "const file = unsafe;" | "$1" fingerprint MiguelRodo/actions prebuild-devcontainer/action.yml code-injection inject-build-info' _ "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "$first" ]
  [[ "$output" =~ ^\<\!--\ sentinel-fingerprint:v2: ]]
}

@test "changed vulnerable hunks produce a new fingerprint" {
  run bash -c 'printf %s "const file = unsafe;" | "$1" fingerprint MiguelRodo/actions prebuild-devcontainer/action.yml code-injection inject-build-info' _ "$SCRIPT"
  [ "$status" -eq 0 ]
  first="$output"

  run bash -c 'printf %s "const file = changed;" | "$1" fingerprint MiguelRodo/actions prebuild-devcontainer/action.yml code-injection inject-build-info' _ "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" != "$first" ]
}

@test "empty vulnerable hunks are rejected" {
  run "$SCRIPT" fingerprint MiguelRodo/actions path/action.yml code-injection step
  [ "$status" -eq 2 ]
  [[ "$output" == *"must not be empty"* ]]
}

@test "the oldest open PR remains canonical" {
  run "$SCRIPT" deduplicate MiguelRodo/actions 10
  [ "$status" -eq 0 ]
  [[ "$output" == "#10 is the canonical open remediation"* ]]
  run grep -q '^pr close' "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "a newer PR with the same fingerprint is closed" {
  run "$SCRIPT" deduplicate MiguelRodo/actions 11
  [ "$status" -eq 0 ]
  [[ "$output" == "Closed #11 as a duplicate of #10"* ]]
  grep -q '^pr comment 11 ' "$MOCK_LOG"
  grep -q '^pr close 11 ' "$MOCK_LOG"
}

@test "external contributors cannot spoof a Sentinel fingerprint" {
  run "$SCRIPT" deduplicate MiguelRodo/actions 12
  [ "$status" -eq 0 ]
  [[ "$output" == "Skipping #12: author contributor is not repository owner MiguelRodo." ]]
  run grep -q '^pr close' "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "dry-run reports a duplicate without changing pull requests" {
  SENTINEL_DEDUP_DRY_RUN=true run "$SCRIPT" deduplicate MiguelRodo/actions 11
  [ "$status" -eq 0 ]
  [[ "$output" == "Would close #11 as a duplicate of #10"* ]]
  run grep -q '^pr comment' "$MOCK_LOG"
  [ "$status" -ne 0 ]
  run grep -q '^pr close' "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

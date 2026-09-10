#!/usr/bin/env bats

HELPER="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/git-auth-askpass.sh"
REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
  export RUNNER_TEMP="$BATS_TEST_TMPDIR"
  export GIT_TOKEN_FOR_ASKPASS="test-token-value"
  source "$HELPER"
}

teardown() {
  cleanup_git_askpass
}

@test "git askpass helper returns credentials and cleans up temporary state" {
  setup_git_askpass
  askpass_path="$GIT_ASKPASS"
  askpass_dir="$GIT_ASKPASS_DIR"

  [ "$(stat -c '%a' "$askpass_dir")" = "700" ]
  [ "$(stat -c '%a' "$askpass_path")" = "700" ]
  [ "$($askpass_path 'Username for https://github.com')" = "x-access-token" ]
  [ "$($askpass_path 'Password for https://github.com')" = "test-token-value" ]

  cleanup_git_askpass
  [ ! -e "$askpass_dir" ]
  [ -z "${GIT_ASKPASS:-}" ]
  [ -z "${GIT_TOKEN_FOR_ASKPASS:-}" ]
}

@test "failed authenticated Git operation removes helper without persisting the token" {
  home_dir="$BATS_TEST_TMPDIR/home"
  repo_dir="$BATS_TEST_TMPDIR/repo"
  path_file="$BATS_TEST_TMPDIR/askpass-dir"
  port_file="$BATS_TEST_TMPDIR/server-port"
  mkdir -p "$home_dir" "$repo_dir"
  git -C "$repo_dir" init --quiet
  git -C "$repo_dir" remote add origin "https://github.com/example/repo.git"

  cat > "$BATS_TEST_TMPDIR/auth-server.py" <<'PYTHON'
import http.server
import sys

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="test"')
        self.end_headers()

    def log_message(self, *_args):
        pass

server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w", encoding="utf-8") as port_file:
    port_file.write(str(server.server_port))
server.serve_forever()
PYTHON
  python3 "$BATS_TEST_TMPDIR/auth-server.py" "$port_file" &
  server_pid=$!
  for _ in {1..50}; do
    [ -s "$port_file" ] && break
    sleep 0.02
  done
  [ -s "$port_file" ]

  run env HOME="$home_dir" RUNNER_TEMP="$BATS_TEST_TMPDIR" bash -c '
    source "$1"
    export GIT_TOKEN_FOR_ASKPASS="test-token-value"
    setup_git_askpass
    printf "%s\n" "$GIT_ASKPASS_DIR" > "$2"
    trap cleanup_git_askpass EXIT
    git ls-remote "http://127.0.0.1:$3/example.git"
  ' _ "$HELPER" "$path_file" "$(cat "$port_file")"
  operation_status=$status
  kill "$server_pid"
  wait "$server_pid" 2>/dev/null || true

  [ "$operation_status" -ne 0 ]
  [ ! -e "$(cat "$path_file")" ]
  [ ! -e "$home_dir/.gitconfig" ]
  [[ "$(git -C "$repo_dir" remote get-url origin)" != *test-token-value* ]]
}

@test "authenticated actions avoid persistent token-bearing git configuration and remotes" {
  credential_files=(
    "$REPO_ROOT/setup-project-infrastructure/action.yml"
    "$REPO_ROOT/apt-repo-prune/action.yml"
    "$REPO_ROOT/go-version-release/action.yml"
    "$REPO_ROOT/rust-version-release/action.yml"
    "$REPO_ROOT/scripts/publish-apt-repository.sh"
  )
  helper_users=(
    "$REPO_ROOT/setup-project-infrastructure/action.yml"
    "$REPO_ROOT/apt-repo-prune/action.yml"
    "$REPO_ROOT/scripts/publish-apt-repository.sh"
  )

  run grep -E 'git config --global url\.|git remote (add|set-url).*x-access-token|git clone .*x-access-token' "${credential_files[@]}"
  [ "$status" -ne 0 ]

  for helper_user in "${helper_users[@]}"; do
    run grep -F 'git-auth-askpass.sh' "$helper_user"
    [ "$status" -eq 0 ]
  done
}

#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/publish-apt-repository.sh"

setup() {
  export TEST_ROOT="$BATS_TEST_TMPDIR/work"
  export FAKE_BIN="$BATS_TEST_TMPDIR/bin"
  export FAKE_GIT_LOG="$BATS_TEST_TMPDIR/git.log"
  export TEST_SNAPSHOT="$BATS_TEST_TMPDIR/published-repository"
  mkdir -p "$TEST_ROOT" "$FAKE_BIN"

  cat > "$FAKE_BIN/dpkg-deb" <<'EOF'
#!/usr/bin/env bash
case "$3" in
  Package) printf 'demo\n' ;;
  Architecture) printf 'amd64\n' ;;
  *) exit 1 ;;
esac
EOF

  cat > "$FAKE_BIN/dpkg-scanpackages" <<'EOF'
#!/usr/bin/env bash
printf 'Package: demo\nArchitecture: amd64\nFilename: pool/main/d/demo_1.0.0_amd64.deb\n'
EOF

  cat > "$FAKE_BIN/apt-ftparchive" <<'EOF'
#!/usr/bin/env bash
printf 'Suite: stable\nArchitectures: amd64\nComponents: main\n'
EOF

  cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GIT_LOG"
case "$1" in
  clone)
    destination="${*: -1}"
    mkdir -p "$destination/.git"
    ;;
  config|add|commit)
    ;;
  diff)
    exit 1
    ;;
  push)
    rm -rf "$TEST_SNAPSHOT"
    cp -a . "$TEST_SNAPSHOT"
    ;;
  *)
    echo "Unexpected git invocation: $*" >&2
    exit 1
    ;;
esac
EOF

  chmod +x "$FAKE_BIN"/*
}

run_publisher() {
  run env \
    PATH="$FAKE_BIN:$PATH" \
    APT_REPO_INPUT="${APT_REPO_INPUT:-owner/packages}" \
    APT_REPO_TOKEN="apt-token" \
    GITHUB_TOKEN_INPUT="github-token" \
    APT_SIGNING_KEY="" \
    APT_SIGNING_KEY_PASSPHRASE="" \
    TAG="v1.2.3" \
    GITHUB_SERVER_URL="https://github.com" \
    RUNNER_TEMP="$BATS_TEST_TMPDIR" \
    "$SCRIPT"
}

@test "publisher fails when apt publishing is requested without Debian packages" {
  cd "$TEST_ROOT"

  run_publisher

  [ "$status" -eq 1 ]
  [[ "$output" == *"no .deb files were found in dist/"* ]]
}

@test "publisher rejects an invalid apt repository name" {
  mkdir -p "$TEST_ROOT/dist"
  touch "$TEST_ROOT/dist/demo_1.0.0_amd64.deb"
  cd "$TEST_ROOT"
  APT_REPO_INPUT="invalid-repository"

  run_publisher

  [ "$status" -eq 1 ]
  [[ "$output" == *"apt_repo must be in owner/name format"* ]]
}

@test "publisher builds unsigned multi-architecture metadata and pushes it" {
  mkdir -p "$TEST_ROOT/dist"
  printf 'fake deb\n' > "$TEST_ROOT/dist/demo_1.0.0_amd64.deb"
  cd "$TEST_ROOT"

  run_publisher

  [ "$status" -eq 0 ]
  [ -f "$TEST_SNAPSHOT/pool/main/d/demo_1.0.0_amd64.deb" ]
  [ -f "$TEST_SNAPSHOT/dists/stable/main/binary-amd64/Packages" ]
  [ -f "$TEST_SNAPSHOT/dists/stable/main/binary-amd64/Packages.gz" ]
  [ -f "$TEST_SNAPSHOT/dists/stable/Release" ]
  [ ! -e "$TEST_SNAPSHOT/dists/stable/InRelease" ]
  grep -q '^commit -m Publish Debian packages for v1.2.3$' "$FAKE_GIT_LOG"
  grep -q '^push origin HEAD:main$' "$FAKE_GIT_LOG"
}

@test "Go and Rust release actions call the shared publisher through environment data" {
  for action in go-version-release/action.yml rust-version-release/action.yml; do
    # These are literal GitHub expression and runner variable references in action YAML.
    # shellcheck disable=SC2016
    run grep -F 'run: "$GITHUB_ACTION_PATH/../scripts/publish-apt-repository.sh"' "$ROOT_DIR/$action"
    [ "$status" -eq 0 ]
    # shellcheck disable=SC2016
    run grep -F 'APT_REPO_INPUT: ${{ inputs.apt_repo }}' "$ROOT_DIR/$action"
    [ "$status" -eq 0 ]
    # shellcheck disable=SC2016
    run grep -F 'APT_SIGNING_KEY: ${{ inputs.apt_signing_key }}' "$ROOT_DIR/$action"
    [ "$status" -eq 0 ]
  done
}

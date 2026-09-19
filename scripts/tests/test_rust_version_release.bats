#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTION_FILE="$ROOT_DIR/rust-version-release/action.yml"
SCRIPT="$ROOT_DIR/scripts/update-cargo-version.sh"

@test "rust-version-release action exists and is a composite action" {
  run cat "$ACTION_FILE"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" =~ "Rust Version and Release" ]]
  [[ "$output" =~ "using: \"composite\"" ]]
}

@test "rust-version-release inputs include github_token, apt inputs, and rust_version defaults" {
  run grep "github_token:" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep "apt_repo:" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -A 3 "rust_version:" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ default:\ \"stable\" ]]
}

@test "rust-version-release updates only the Cargo package version" {
  cargo_toml="$BATS_TEST_TMPDIR/Cargo.toml"
  cat > "$cargo_toml" <<'TOML'
[package]
name = "example"
version = "1.2.3"
edition = "2021"

[dependencies.serde]
version = "1.0.0"
features = ["derive"]
TOML

  run bash "$SCRIPT" 2.0.1 "$cargo_toml"
  [ "$status" -eq 0 ]

  run grep -Fx 'version = "2.0.1"' "$cargo_toml"
  [ "$status" -eq 0 ]
  run grep -Fx 'version = "1.0.0"' "$cargo_toml"
  [ "$status" -eq 0 ]
}

@test "rust-version-release rejects an invalid Cargo version without changing the file" {
  cargo_toml="$BATS_TEST_TMPDIR/Cargo.toml"
  printf '[package]\nname = "example"\nversion = "1.2.3"\n' > "$cargo_toml"
  before="$(cat "$cargo_toml")"

  run bash "$SCRIPT" '2.0.1; touch nope' "$cargo_toml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid semver"* ]]
  [ "$(cat "$cargo_toml")" = "$before" ]
  [ ! -e "$BATS_TEST_TMPDIR/nope" ]
}

@test "rust-version-release action delegates Cargo mutation to the tested helper" {
  run grep -F 'bash "$GITHUB_ACTION_PATH/../scripts/update-cargo-version.sh" "$NEW_VERSION" Cargo.toml' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'sed -i "s/^version =' "$ACTION_FILE"
  [ "$status" -ne 0 ]
}

@test "rust-version-release action sets up Rust" {
  run grep "Setup Rust" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep "uses: dtolnay/rust-toolchain@" "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "rust-version-release builds Debian packages into the release handoff directory" {
  work_dir="$BATS_TEST_TMPDIR/rust-build"
  fake_bin="$work_dir/bin"
  mkdir -p "$fake_bin"

  cat > "$fake_bin/cargo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CARGO_LOG"
if [ "${1:-}" = "deb" ]; then
  mkdir -p dist
  printf 'fake deb\n' > dist/example_1.2.3_amd64.deb
fi
SH
  chmod +x "$fake_bin/cargo"

  build_commands="$(
    sed -n '
      /- name: Build Debian packages/,/- name: Create or verify base tag/ {
        /^[[:space:]]*cargo / {
          s/^[[:space:]]*//
          p
        }
      }
    ' "$ACTION_FILE"
  )"
  [ -n "$build_commands" ]

  run bash -c "cd \"$work_dir\" && PATH=\"$fake_bin:\$PATH\" CARGO_LOG=\"$work_dir/cargo.log\" bash -c '$build_commands'"
  [ "$status" -eq 0 ]

  run cat "$work_dir/cargo.log"
  [ "$status" -eq 0 ]
  [ "$output" = $'install cargo-deb\ndeb --output dist/' ]
  [ -f "$work_dir/dist/example_1.2.3_amd64.deb" ]

  run grep -F 'files: dist/*' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F "find dist -type f -name '*.deb'" "$ROOT_DIR/scripts/publish-apt-repository.sh"
  [ "$status" -eq 0 ]
}

@test "rust-version-release action publishes GitHub Release" {
  run grep "Publish GitHub Release" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep "uses: softprops/action-gh-release@" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep "files: dist/\\*" "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

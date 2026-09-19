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

@test "rust-version-release updates the Cargo package version" {
  cargo_toml="$BATS_TEST_TMPDIR/Cargo.toml"
  cat > "$cargo_toml" <<'TOML'
[package]
name = "example"
version = "1.2.3"
edition = "2021"

[dependencies]
serde = { version = "1", features = ["derive"] }
TOML

  run bash "$SCRIPT" 2.0.1 "$cargo_toml"
  [ "$status" -eq 0 ]

  run grep -Fx 'version = "2.0.1"' "$cargo_toml"
  [ "$status" -eq 0 ]
  run grep -Fx 'serde = { version = "1", features = ["derive"] }' "$cargo_toml"
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

@test "rust-version-release action builds Debian packages natively" {
  run grep "Build Debian packages" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep "cargo install cargo-deb" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep "cargo deb --output dist/" "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "rust-version-release action publishes GitHub Release" {
  run grep "Publish GitHub Release" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep "uses: softprops/action-gh-release@" "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep "files: dist/\*" "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

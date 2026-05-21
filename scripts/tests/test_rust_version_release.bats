#!/usr/bin/env bats

@test "rust-version-release action exists and is a composite action" {
  run cat rust-version-release/action.yml
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" =~ "Rust Version and Release" ]]
  [[ "$output" =~ "using: \"composite\"" ]]
}

@test "rust-version-release inputs include github_token, apt inputs, and rust_version defaults" {
  run grep "github_token:" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  run grep "apt_repo:" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  run grep -A 3 "rust_version:" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  [[ "$output" =~ default:\ \"stable\" ]]
}

@test "rust-version-release action sets up Rust and updates Cargo.toml" {
  run grep "Setup Rust" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  run grep "uses: dtolnay/rust-toolchain@master" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  run grep "Update Cargo.toml version" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  run grep "sed -i \"s/^version =" rust-version-release/action.yml
  [ "$status" -eq 0 ]
}

@test "rust-version-release action builds Debian packages natively" {
  run grep "Build Debian packages" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  run grep "cargo install cargo-deb" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  run grep "cargo deb --output dist/" rust-version-release/action.yml
  [ "$status" -eq 0 ]
}

@test "rust-version-release action publishes GitHub Release" {
  run grep "Publish GitHub Release" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  run grep "uses: softprops/action-gh-release@v2" rust-version-release/action.yml
  [ "$status" -eq 0 ]
  run grep "files: dist/\*" rust-version-release/action.yml
  [ "$status" -eq 0 ]
}

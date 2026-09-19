#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

RELEASE_ACTIONS=(
  version-release
  r-version-release
  go-version-release
  rust-version-release
)

MANUAL_VERSION_SOURCES=(
  "$ROOT_DIR/examples/version-release.yml"
  "$ROOT_DIR/r-version-release/README.md"
  "$ROOT_DIR/go-version-release/README.md"
  "$ROOT_DIR/rust-version-release/README.md"
  "$ROOT_DIR/examples/prebuild-devcontainer.yml"
)

@test "all action inputs have user-facing descriptions" {
  run python3 -c '
import importlib.util
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
path = root / "scripts" / "generate-action-docs.py"
spec = importlib.util.spec_from_file_location("generate_action_docs", path)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)

missing = []
for action_path in sorted(root.glob("*/action.yml")):
    action = module.parse_action(action_path)
    for item in action.inputs:
        if not item.description.strip():
            missing.append(f"{action.slug}:{item.name}")

if missing:
    raise SystemExit("missing input descriptions: " + ", ".join(missing))
' "$ROOT_DIR"

  [ "$status" -eq 0 ]
}

@test "release actions expose the same shared version controls" {
  for action in "${RELEASE_ACTIONS[@]}"; do
    file="$ROOT_DIR/$action/action.yml"

    version_block="$(grep -A 6 '^  version:$' "$file")"
    [[ "$version_block" == *"Exact release version in X.Y.Z form"* ]]
    [[ "$version_block" == *'default: ""'* ]]

    bump_block="$(grep -A 5 '^  bump_type:$' "$file")"
    [[ "$bump_block" == *"patch, minor, or major"* ]]
    [[ "$bump_block" == *'default: ""'* ]]

    force_block="$(grep -A 4 '^  version_force:$' "$file")"
    [[ "$force_block" == *"non-sequential versions"* ]]
    [[ "$force_block" == *'default: "false"'* ]]
  done
}

@test "manual version workflows use the same exact-or-component controls" {
  for file in "${MANUAL_VERSION_SOURCES[@]}"; do
    version_block="$(grep -A 4 '^      version:$' "$file" | head -n 5)"
    [[ "$version_block" == *"type: string"* ]]
    [[ "$version_block" == *"X.Y.Z"* || "$file" == *"prebuild-devcontainer.yml"* ]]

    bump_block="$(grep -A 12 '^      bump_type:$' "$file" | head -n 13)"
    [[ "$bump_block" == *"type: choice"* ]]
    [[ "$bump_block" == *"default: none"* ]]
    [[ "$bump_block" == *"- none"* ]]
    [[ "$bump_block" == *"- patch"* ]]
    [[ "$bump_block" == *"- minor"* ]]
    [[ "$bump_block" == *"- major"* ]]

    force_block="$(grep -A 5 '^      version_force:$' "$file" | head -n 6)"
    [[ "$force_block" == *"type: boolean"* ]]
    [[ "$force_block" == *"default: false"* ]]

    run grep -F "inputs.bump_type != 'none'" "$file"
    [ "$status" -eq 0 ]
  done
}

@test "manual workflow inputs are described immediately and concisely" {
  sources=(
    "${MANUAL_VERSION_SOURCES[@]}"
    "$ROOT_DIR/apt-repo-prune/README.md"
  )

  for file in "${sources[@]}"; do
    run awk '
      /^  workflow_dispatch:/ { in_dispatch = 1; next }
      in_dispatch && /^    inputs:/ { in_inputs = 1; next }
      in_inputs && /^      [A-Za-z0-9_.-]+:/ {
        key = $1
        if ((getline next_line) <= 0 || next_line !~ /^[[:space:]]+description:/) {
          print "missing description after " key
          exit 1
        }
      }
      in_inputs && (/^jobs:/ || /^  schedule:/) { exit }
    ' "$file"
    [ "$status" -eq 0 ]
  done
}

@test "release manual forms keep credentials in secrets rather than dispatch inputs" {
  for file in "$ROOT_DIR/go-version-release/README.md" "$ROOT_DIR/rust-version-release/README.md"; do
    dispatch_block="$(sed -n '/^  workflow_dispatch:/,/^jobs:/p' "$file")"
    [[ "$dispatch_block" != *"apt_repo_token:"* ]]
    [[ "$dispatch_block" != *"apt_signing_key:"* ]]
    [[ "$dispatch_block" != *"apt_signing_key_passphrase:"* ]]

    run grep -F 'apt_repo_token: ${{ secrets.APT_REPO_TOKEN }}' "$file"
    [ "$status" -eq 0 ]
    run grep -F 'apt_signing_key: ${{ secrets.APT_SIGNING_KEY }}' "$file"
    [ "$status" -eq 0 ]
  done
}

@test "APT retention is a choice input" {
  file="$ROOT_DIR/apt-repo-prune/README.md"
  retention_block="$(grep -A 9 '^      retention:$' "$file" | head -n 10)"
  [[ "$retention_block" == *"type: choice"* ]]
  [[ "$retention_block" == *"default: latest-per-major"* ]]
  [[ "$retention_block" == *"- latest-per-major"* ]]
  [[ "$retention_block" == *"- latest-per-minor"* ]]
  [[ "$retention_block" == *"- latest"* ]]
}

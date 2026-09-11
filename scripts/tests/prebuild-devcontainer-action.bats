#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTION_FILE="$ROOT_DIR/prebuild-devcontainer/action.yml"
INJECTOR="$ROOT_DIR/scripts/inject-build-info.js"
FILES_SCRIPT="$ROOT_DIR/scripts/prebuild-devcontainer-files.sh"

@test "prebuild-devcontainer remains a composite action with required integrations" {
  run grep -F 'using: "composite"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'uses: docker/login-action@' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'uses: devcontainers/ci@' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "devcontainer path resolution preserves shell metacharacters as data" {
  path='workspace/quote '"'"' $(touch should-not-exist) {"json":true}/.devcontainer/'

  run "$FILES_SCRIPT" resolve "$path"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]
  run jq -e '
    .path == "workspace/quote '\'' $(touch should-not-exist) {\"json\":true}/.devcontainer" and
    .subfolder == "workspace/quote '\'' $(touch should-not-exist) {\"json\":true}"
  ' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "devcontainer path resolution rejects absolute traversal and newline injection" {
  run "$FILES_SCRIPT" resolve "/tmp/.devcontainer"
  [ "$status" -ne 0 ]
  [[ "$output" == *"relative"* ]]

  run "$FILES_SCRIPT" resolve "../outside/.devcontainer"
  [ "$status" -ne 0 ]
  [[ "$output" == *"traverse"* ]]

  run "$FILES_SCRIPT" resolve $'.devcontainer\nINJECTED=value'
  [ "$status" -ne 0 ]
  [[ "$output" == *"control characters"* ]]

  run "$FILES_SCRIPT" resolve $'.devcontainer/\001hidden'
  [ "$status" -ne 0 ]
  [[ "$output" == *"control characters"* ]]
}

@test "injector treats an exploit-shaped devcontainer path purely as data" {
  devcontainer_dir="$BATS_TEST_TMPDIR/path with spaces/quote '; throw new Error(\"injected\"); //back\\slash"
  devcontainer_json="$devcontainer_dir/devcontainer.json"
  mkdir -p "$devcontainer_dir"
  cat > "$devcontainer_json" <<'JSON'
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/build-info:1": {
      "existing": "preserved"
    },
    "other-feature": {
      "value": 42
    }
  }
}
JSON

  run env DEVCONTAINER_JSON="$devcontainer_json" IMAGE_VERSION="v9.8.7" node "$INJECTOR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$devcontainer_json"* ]]

  run jq -e '
    .features["ghcr.io/MiguelRodo/DevContainerFeatures/build-info:1"] == {
      "existing": "preserved",
      "imageVersion": "v9.8.7"
    }
    and .features["other-feature"].value == 42
  ' "$devcontainer_json"
  [ "$status" -eq 0 ]
}

@test "prebuild JSON creation preserves customizations and safely encodes the image" {
  devcontainer_path="$BATS_TEST_TMPDIR/path with spaces/'quote \$(touch should-not-exist)/.devcontainer"
  image='ghcr.io/octo/image:tag-{"json":true}-$(echo safe)'
  mkdir -p "$devcontainer_path"
  cat > "$devcontainer_path/devcontainer.json" <<'JSON'
{
  "features": {"ignored": true},
  "customizations": {
    "vscode": {"extensions": ["one", "two"]}
  }
}
JSON

  run "$FILES_SCRIPT" update-prebuild-json "$devcontainer_path" "$image"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/should-not-exist" ]
  run jq -e --arg image "$image" '
    .image == $image and
    .customizations.vscode.extensions == ["one", "two"] and
    has("features") == false
  ' "$devcontainer_path/prebuild/devcontainer.json"
  [ "$status" -eq 0 ]
}

@test "prebuild JSON updates only the image in an existing generated file" {
  devcontainer_path="$BATS_TEST_TMPDIR/.devcontainer"
  mkdir -p "$devcontainer_path/prebuild"
  cat > "$devcontainer_path/prebuild/devcontainer.json" <<'JSON'
{"image":"old","customizations":{"vscode":{"settings":{"x":1}}},"extra":"preserved"}
JSON

  run "$FILES_SCRIPT" update-prebuild-json "$devcontainer_path" "new:image"
  [ "$status" -eq 0 ]
  run jq -e '
    .image == "new:image" and
    .customizations.vscode.settings.x == 1 and
    .extra == "preserved"
  ' "$devcontainer_path/prebuild/devcontainer.json"
  [ "$status" -eq 0 ]
}

@test "prebuild JSON creation fails when the source devcontainer is absent" {
  run "$FILES_SCRIPT" update-prebuild-json "$BATS_TEST_TMPDIR/missing" "image:tag"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No devcontainer.json found"* ]]
}

@test "action wires resolved paths and generated prebuild JSON through the helpers" {
  run grep -F 'scripts/prebuild-devcontainer-files.sh' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'DEVCONTAINER_PATH=%s' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

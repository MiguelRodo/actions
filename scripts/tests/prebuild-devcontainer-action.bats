#!/usr/bin/env bats

ACTION_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/prebuild-devcontainer/action.yml"

@test "prebuild-devcontainer action exists and is a composite action" {
  [ -f "$ACTION_FILE" ]
  run grep -F 'using: "composite"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "prebuild-devcontainer inputs include required and optional inputs" {
  run grep -F 'github_token:' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'no_cache:' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'create_prebuild_json:' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'devcontainer_path:' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'image_name:' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'tag:' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'registry:' "$ACTION_FILE"
  [ "$status" -eq 0 ]

  run grep -F 'version_force:' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "prebuild-devcontainer logs into container registry" {
  run grep -F 'uses: docker/login-action@v3' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'registry: ${{ inputs.registry }}' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "prebuild-devcontainer calls devcontainers/ci@v0.3 to build and push" {
  run grep -F 'uses: devcontainers/ci@v0.3' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'imageName: ${{ env.IMAGE_NAME }}' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'imageTag: ${{ env.IMAGE_TAG }}' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'push: always' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'noCache: ${{ inputs.no_cache }}' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'subFolder: ${{ env.DEVCONTAINER_SUBFOLDER }}' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "prebuild-devcontainer updates or creates prebuild/devcontainer.json" {
  run grep -F 'Update or create prebuild/devcontainer.json' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'if: ${{ inputs.create_prebuild_json == '"'"'true'"'"' }}' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'jq --arg image "$FULL_IMAGE_REF" '"'"'.image = $image'"'"' "$PREBUILD_JSON" > temp.json && mv temp.json "$PREBUILD_JSON"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "prebuild-devcontainer commits and pushes changes when create_prebuild_json is true" {
  run grep -F 'Commit and push changes' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'git commit -m "Update prebuild devcontainer.json with image ${IMAGE_NAME}:${IMAGE_TAG}"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "prebuild-devcontainer verifies version progression" {
  run grep -F 'Check version progression' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F '"$GITHUB_ACTION_PATH/../scripts/check-version-progression.sh" "${NEW_VERSION}" "${PREV_VERSION}"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

@test "prebuild-devcontainer tags and pushes alias images" {
  run grep -F 'Tag and push SemVer alias images' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:${alias_tag}"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
  run grep -F 'docker push "${IMAGE_NAME}:${alias_tag}"' "$ACTION_FILE"
  [ "$status" -eq 0 ]
}

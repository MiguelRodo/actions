#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
PARSER="$ROOT_DIR/scripts/parse-delimited-json.sh"

@test "delimited input safely encodes hostile values and ignores empty entries" {
  run "$PARSER" ' dplyr ; quoted "pkg" ; C:\\packages ; ; {"json":true} '
  [ "$status" -eq 0 ]
  run jq -e 'length == 4 and .[0] == "dplyr" and .[1] == "quoted \\"pkg\\"" and .[2] == "C:\\\\packages" and .[3] == "{\\"json\\":true}"' <<< "$output"
  [ "$status" -eq 0 ]
}

@test "empty and repeated delimiters produce an empty JSON array" {
  run "$PARSER" ', ; ;'
  [ "$status" -eq 0 ]
  [ "$output" = '[]' ]
}

@test "parsed arrays can be inserted into a valid devcontainer document" {
  pkgs_json=$("$PARSER" 'pkg one;pkg"two')
  repos_json=$("$PARSER" 'https://example.test/a;b\\c')

  run jq -n --argjson pkgs "$pkgs_json" --argjson repos "$repos_json" \
    '{features: {"ghcr.io/miguelrodo/devcontainers/renv-cache:latest": {pkg: $pkgs, repos: $repos}}}'
  [ "$status" -eq 0 ]
  run jq -e '.features["ghcr.io/miguelrodo/devcontainers/renv-cache:latest"].pkg == ["pkg one", "pkg\\"two"]' <<< "$output"
  [ "$status" -eq 0 ]
}

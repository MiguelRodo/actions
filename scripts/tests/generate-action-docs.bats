#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TMP_ROOT="$(mktemp -d)"
  mkdir -p "$TMP_ROOT/demo"

  cat > "$TMP_ROOT/demo/action.yml" <<'YAML'
name: "Demo Action"
description: >
  Demonstrates generated docs for inputs | outputs.
inputs:
  mode:
    description: >
      Version component (major | minor | patch).
    required: false
    default: "false"
  token:
    description: "Token used by the demo."
    required: true
outputs:
  result:
    description: "Generated result."
    value: ${{ steps.demo.outputs.result }}
runs:
  using: composite
  steps: []
YAML

  cat > "$TMP_ROOT/demo/README.md" <<'MARKDOWN'
# Demo Action

Narrative before the generated reference.

## Inputs

| Input | Description | Required |
| --- | --- | --- |
| stale | stale | stale |

## Outputs

| Output | Description |
| --- | --- |
| stale | stale |

## Notes

Narrative after the generated reference.
MARKDOWN

  cat > "$TMP_ROOT/demo.qmd" <<'MARKDOWN'
---
title: "Demo"
---

Quarto-specific narrative.

## Inputs

Old input table.

## Outputs

Old output table.

## Notes

Keep this section.
MARKDOWN

  cat > "$TMP_ROOT/README.md" <<'MARKDOWN'
# Old root README

Duplicated action documentation that should be replaced during migration.
MARKDOWN

  cat > "$TMP_ROOT/index.qmd" <<'MARKDOWN'
---
title: "Actions"
---

## Available Actions

| Action | Description |
| --- | --- |
| Old | Old |

## Usage

Keep this section.
MARKDOWN
}

teardown() {
  rm -rf "$TMP_ROOT"
}

@test "write generates bounded references and catalogues from action.yml" {
  run python3 "$REPO_ROOT/scripts/generate-action-docs.py" --root "$TMP_ROOT" --write
  [ "$status" -eq 0 ]

  grep -Fq '<!-- action-inputs:start -->' "$TMP_ROOT/demo/README.md"
  grep -Fq '<!-- action-outputs:start -->' "$TMP_ROOT/demo/README.md"
  grep -Fq '| `mode` | Version component (major \| minor \| patch). | No | `false` |' "$TMP_ROOT/demo/README.md"
  grep -Fq '| `token` | Token used by the demo. | Yes | — |' "$TMP_ROOT/demo/README.md"
  grep -Fq '| `result` | Generated result. |' "$TMP_ROOT/demo/README.md"
  grep -Fq 'Narrative before the generated reference.' "$TMP_ROOT/demo/README.md"
  grep -Fq 'Narrative after the generated reference.' "$TMP_ROOT/demo/README.md"

  grep -Fq 'Quarto-specific narrative.' "$TMP_ROOT/demo.qmd"
  grep -Fq 'Keep this section.' "$TMP_ROOT/demo.qmd"
  grep -Fq '<!-- action-catalogue:start -->' "$TMP_ROOT/README.md"
  grep -Fq '[Demo Action](./demo/README.md)' "$TMP_ROOT/README.md"
  grep -Fq '[Demo Action](demo.qmd)' "$TMP_ROOT/index.qmd"
  grep -Fq 'Keep this section.' "$TMP_ROOT/index.qmd"

  run python3 "$REPO_ROOT/scripts/generate-action-docs.py" --root "$TMP_ROOT" --check
  [ "$status" -eq 0 ]
}

@test "check reports docs stale after action metadata changes" {
  python3 "$REPO_ROOT/scripts/generate-action-docs.py" --root "$TMP_ROOT" --write >/dev/null
  sed -i 's/default: "false"/default: "true"/' "$TMP_ROOT/demo/action.yml"

  run python3 "$REPO_ROOT/scripts/generate-action-docs.py" --root "$TMP_ROOT" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"demo/README.md"* ]]
  [[ "$output" == *"demo.qmd"* ]]
}

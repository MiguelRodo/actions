# Version and Release Action

A composite GitHub Action that:

1. Determines the next version (from a tag push, an explicit `version` input, or a `bump_type`).
2. Automatically bumps the version in **Python** (`pyproject.toml`) and/or **R** (`DESCRIPTION`) packages — only when those files are present in the repository root.
3. Commits any version-file changes back to the repository.
4. Creates (or verifies) a versioned git tag (`vX.Y.Z`) and updates floating major (`vX`) and minor (`vX.Y`) tags.
5. Publishes a GitHub Release with auto-generated release notes.

## Quick Start

Copy the following to `.github/workflows/version-release.yml` in your repository:

```yaml
name: Version and Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'
  workflow_dispatch:
    inputs:
      version:
        description: >
          Exact version to apply to all packages (e.g. 1.2.3).
          Cannot be set together with bump_type.
        required: false
      bump_type:
        description: >
          Version component to bump (major | minor | patch).
          Cannot be set together with version.
        required: false
      python_version:
        description: 'Override: exact version to set for the Python package (e.g. 1.2.3).'
        required: false
      r_version:
        description: 'Override: exact version to set for the R package (e.g. 1.2.3).'
        required: false

jobs:
  version-release:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Version and Release
        uses: MiguelRodo/actions/version-release@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          version: ${{ inputs.version }}
          bump_type: ${{ inputs.bump_type }}
          python_version: ${{ inputs.python_version }}
          r_version: ${{ inputs.r_version }}
```

## Inputs

| Input | Description | Required |
|---|---|---|
| `github_token` | GitHub token for pushing tags and creating releases. | **Yes** |
| `version` | Exact version to apply to all packages (e.g. `1.2.3`). Cannot be used with `bump_type`. | No |
| `bump_type` | Version component to bump: `major`, `minor`, or `patch`. Cannot be used with `version`. | No |
| `python_version` | Per-package override: exact version for the Python package. | No |
| `r_version` | Per-package override: exact version for the R package. | No |

## Outputs

| Output | Description |
|---|---|
| `version` | Released version without a leading `v` (e.g. `1.2.3`). |
| `tag` | Git tag that was created (e.g. `v1.2.3`). |

## How it works

### Trigger: tag push (`v*`)

The version is taken directly from the pushed tag (e.g. `v1.2.3` → `1.2.3`). The `version` and `bump_type` inputs are ignored.

### Trigger: `workflow_dispatch`

Exactly one of the following must be supplied:

- **`version`** — use an explicit version for all packages (e.g. `1.2.3`).
- **`bump_type`** — derive the new version by bumping the most recent semver git tag.

The `python_version` and `r_version` inputs always override the global `version` for their respective packages.

### Python package (`pyproject.toml`)

If `pyproject.toml` is present in the repository root, the action reads the current `version = "X.Y.Z"` field and updates it to the resolved Python version. If the file is absent the step is silently skipped.

### R package (`DESCRIPTION`)

If `DESCRIPTION` is present in the repository root, the action reads the current `Version: X.Y.Z` field and updates it to the resolved R version. If the file is absent the step is silently skipped.

### Version precedence (per package)

| Priority | Source |
|---|---|
| 1 (highest) | `python_version` / `r_version` input |
| 2 | Global `version` input |
| 3 | Bump the current file version using `bump_type` |
| 4 | Use the tag pushed (tag-push trigger) |

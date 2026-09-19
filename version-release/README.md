# Version and Release Action

A composite GitHub Action that:

1. Determines the next version (from a tag push, an explicit `version` input, or a `bump_type`).
2. Automatically bumps the version in **Python** (`pyproject.toml`) and/or **R** (`DESCRIPTION`) packages — only when those files are present in the repository root.
3. Commits any version-file changes back to the repository.
4. Creates (or verifies) a versioned git tag (`vX.Y.Z`) and updates floating major (`vX`) and minor (`vX.Y`) tags.
5. Publishes a GitHub Release with auto-generated release notes.

## Quick Start

Copy [`examples/version-release.yml`](../examples/version-release.yml) into `.github/workflows/version-release.yml` and adjust the optional version inputs as needed.

## Permissions

The calling workflow needs the following permission:

| Permission | Why it is needed |
| --- | --- |
| `contents: write` | Push version-bump commits, create/update tags, and publish the GitHub Release. |

```yaml
permissions:
  contents: write
```

> **Version pinning:** For stricter supply-chain security, pin to a specific commit SHA instead of a floating tag:
> ```yaml
> uses: MiguelRodo/actions/version-release@<full-commit-sha>
> ```

<!-- action-inputs:start -->
<!-- Generated from version-release/action.yml by scripts/generate-action-docs.py. Do not edit this block manually. -->
## Inputs

| Input | Description | Required | Default |
| --- | --- | :---: | --- |
| `github_token` | GitHub token for pushing tags and creating releases. | Yes | — |
| `version` | Exact release version in X.Y.Z form (e.g. 1.2.3). Leave blank to use bump_type. Overridden per package by python_version or r_version. | No | `""` |
| `bump_type` | Version component to bump: patch, minor, or major. Leave blank when version is set. | No | `""` |
| `python_version` | Optional exact Python version in X.Y.Z form; overrides version. | No | `""` |
| `r_version` | Optional exact R version in X.Y.Z form; overrides version. | No | `""` |
| `version_force` | Set true to allow non-sequential versions (e.g. downgrades or skipped increments). | No | `false` |
<!-- action-inputs:end -->

<!-- action-outputs:start -->
<!-- Generated from version-release/action.yml by scripts/generate-action-docs.py. Do not edit this block manually. -->
## Outputs

| Output | Description |
| --- | --- |
| `version` | Released version without a leading v (e.g. 1.2.3). |
| `tag` | Git tag that was created (e.g. v1.2.3). |
<!-- action-outputs:end -->

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

# Go Version and Release Action

Standalone composite action for pure Go releases. It resolves a semantic version, optionally validates strict progression from the latest semver tag, creates/pushes the release tag, updates floating major/minor tags, sets up Go, and runs GoReleaser.

## Usage

Copy the following to `.github/workflows/go-version-release.yml`:

```yaml
name: Go Version and Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Exact version (e.g. 1.2.3). Cannot be used with bump_type.'
        required: false
      bump_type:
        description: 'Component to bump: major | minor | patch. Cannot be used with version.'
        required: false
      version_check:
        description: 'Run strict version progression checks (true/false).'
        required: false
      go_version:
        description: 'Go version to install.'
        required: false

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: MiguelRodo/actions/go-version-release@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          version: ${{ inputs.version }}
          bump_type: ${{ inputs.bump_type }}
          version_check: ${{ inputs.version_check }}
          go_version: ${{ inputs.go_version }}
```

> [!IMPORTANT]
> Use `fetch-depth: 0` on checkout so the action can inspect existing tags.

## Inputs

| Input | Description | Required |
|---|---|---|
| `github_token` | GitHub token for pushing tags and publishing releases. | **Yes** |
| `version` | Exact version (e.g. `1.2.3`). Cannot be used with `bump_type`. | No |
| `bump_type` | Version component to bump: `major`, `minor`, or `patch`. Cannot be used with `version`. | No |
| `version_check` | When `true` (default), enforce strict progression from latest semver tag. | No |
| `go_version` | Go version for `actions/setup-go` (default `1.22`). | No |

## Outputs

| Output | Description |
|---|---|
| `version` | Released version without leading `v` (e.g. `1.2.3`). |
| `tag` | Released git tag with leading `v` (e.g. `v1.2.3`). |

## Version resolution

- If `bump_type` is provided, the action computes the next version from the latest
  semver tag using `scripts/apply-version-bump.sh`.
- If `version` is provided, it is used directly (after stripping optional leading `v`).
- If neither is provided, tag-triggered workflows use `github.ref_name`.
- If both are provided, the action fails.

## Version progression guard

When `version_check: true`, the action validates the new version against the latest
previous semver tag using `scripts/check-version-progression.sh`.

## Tag behavior

The action creates or reuses the release tag `vX.Y.Z` and also updates floating tags:

- `vX`
- `vX.Y`

For example, releasing `v1.2.3` updates `v1` and `v1.2` to point to the same commit.

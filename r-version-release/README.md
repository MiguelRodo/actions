# R Version and Release

Bumps the version in an R `DESCRIPTION` file, builds the R package as a tarball, creates a versioned git tag with floating major/minor aliases, and publishes a GitHub Release containing the `.tar.gz` package artifact.

This makes it convenient for users to install that specific version (e.g. using `remotes::install_github()` or similar).

## Usage

You must provide exactly one of `version` or `bump_type`.

```yaml
name: R Version and Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'
  workflow_dispatch:
    inputs:
      version:
        description: 'Exact version (e.g. v1.2.3). Cannot be used with bump_type.'
        required: false
      bump_type:
        description: 'Component to bump: major | minor | patch. Cannot be used with version.'
        required: false
      version_force:
        description: 'When true, skip strict version progression checks.'
        required: false
        type: boolean

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: MiguelRodo/actions/r-version-release@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          version: ${{ inputs.version }}
          bump_type: ${{ inputs.bump_type }}
          version_force: ${{ inputs.version_force }}
```

<!-- action-inputs:start -->
<!-- Generated from r-version-release/action.yml by scripts/generate-action-docs.py. Do not edit this block manually. -->
## Inputs

| Input | Description | Required | Default |
| --- | --- | :---: | --- |
| `github_token` | GitHub token for pushing tags and publishing releases. | Yes | — |
| `version` | Exact version to set (e.g. v1.2.3). Cannot be set together with bump_type. Whitespace is ignored and case is insensitive. | No | `""` |
| `bump_type` | Version component to bump (major \| minor \| patch). Cannot be set together with version. Whitespace is ignored and case is insensitive. | No | `""` |
| `version_force` | When true (the default is false), skip strict version progression checks (e.g., allowing downgrades or large version jumps). | No | `false` |
<!-- action-inputs:end -->

<!-- action-outputs:start -->
<!-- Generated from r-version-release/action.yml by scripts/generate-action-docs.py. Do not edit this block manually. -->
## Outputs

| Output | Description |
| --- | --- |
| `version` | Released version without a leading v (e.g. 1.2.3). |
| `tag` | Git tag that was created (e.g. v1.2.3). |
<!-- action-outputs:end -->

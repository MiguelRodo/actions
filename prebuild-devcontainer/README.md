# Pre-build Dev Container Action

**Pre-build Dev Container** is a composite GitHub Action that speeds up Dev Container startup times. It builds your `.devcontainer/Dockerfile` using intelligent caching, tags it with a specified version (or automatically bumps the version), pushes it to a container registry, and optionally generates a `prebuild/devcontainer.json` for instant loads.

## Quick Start

Copy this into `.github/workflows/prebuild-devcontainer.yml`. This example allows you to trigger the build manually and choose whether to specify an exact version or automatically bump the current version.

```yaml
name: 'Pre-build Dev Container'

on:
  push:
    tags:
      - 'v*'
      - '*-v*'
  workflow_dispatch:
    inputs:
      target_branch: 
        description: 'Branch to check out and build (e.g., 2024-stimgate)'
        required: true
        default: 'main'
        type: string
      bump_type:
        description: 'Version component to bump (major, minor, patch)'
        required: false
        type: choice
        options:
          - ''
          - patch
          - minor
          - major
      version:
        description: 'Exact version to build (e.g. v1.2.3). Leave blank if using bump_type.'
        required: false
        type: string

jobs:
  build:
    runs-on: ubuntu-latest
    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}
      cancel-in-progress: true
    permissions:
      contents: write
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          ref: ${{ inputs.target_branch }}
          fetch-depth: 0

      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          target_branch: ${{ inputs.target_branch }}
          bump_type: ${{ github.event.inputs.bump_type }}
          version: ${{ github.event.inputs.version }}

```

## Outputs

| Output | Description |
| --- | --- |
| `image_name` | Full image name without tag (e.g. `ghcr.io/owner/repo-main`). |
| `image_tag` | Primary image tag that was built and pushed (e.g. `v1.2.3`). |
| `image_ref` | Full image reference including tag (e.g. `ghcr.io/owner/repo-main:v1.2.3`). |
| `alias_tags` | Comma-separated list of SemVer alias tags also pushed (e.g. `v1.2,v1`). |

## Permissions

The calling workflow needs the following permissions:

| Permission | Why it is needed |
| --- | --- |
| `contents: write` | Push the updated `prebuild/devcontainer.json` back to the repository. |
| `packages: write` | Push the built container image to the GitHub Container Registry (GHCR) and query packages for version checks. |

```yaml
permissions:
  contents: write
  packages: write

```

> **Version pinning:** For stricter supply-chain security, pin to a specific commit SHA instead of a floating tag:
> ```yaml
> uses: MiguelRodo/actions/prebuild-devcontainer@<full-commit-sha>
> 
> ```
> 
> 

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `github_token` | Token for logging into the container registry and pushing commits. | **Yes** | — |
| `bump_type` | Version component to bump (`major`, `minor`, `patch`). Calculates the next version automatically based on git tags. Cannot be set together with `version`. | No | `""` |
| `version` | Exact version to set (e.g. `v1.2.3` or `main-v1.2.3`). Cannot be set together with `bump_type`. Auto-detected from `GITHUB_REF` on tag push. Falls back to `latest` if no inputs or tags are found. | No | `""` |
| `no_cache` | Disable Docker cache during build (`true`/`false`). | No | `false` |
| `create_prebuild_json` | Generate and commit a `prebuild/devcontainer.json` (`true`/`false`). | No | `true` |
| `devcontainer_path` | Path to the `.devcontainer` directory, relative to the repo root. | No | `.devcontainer` |
| `image_name` | Full image name without tag (e.g. `ghcr.io/myorg/myimage`). Defaults to `{registry}/{repo}-{branch}` where `{branch}` is the current branch name (e.g. `ghcr.io/owner/myrepo-main`). The branch name is always used for the image name even when tagging with SemVer. | No | `{registry}/{repo}-{branch}` |
| `registry` | Container registry URL. | No | `ghcr.io` |
| `registry_username` | Username for registry login. | No | Repository owner |
| `version_force` | When `'true'`, skip the version progression check and push the specified version as-is. Useful when jumping more than one increment at a time or when no previous image exists and you want an explicit override. | No | `false` |

## Outputs

| Output | Description |
| --- | --- |
| `image_name` | Full image name without tag (e.g. `ghcr.io/owner/repo-main`). |
| `image_tag` | Primary image tag that was built and pushed (e.g. `v1.2.3`). |
| `image_ref` | Full image reference including tag (e.g. `ghcr.io/owner/repo-main:v1.2.3`). |
| `alias_tags` | Comma-separated list of SemVer alias tags that were also pushed (e.g. `v1.2,v1`). |

## Intelligent Caching

To drastically reduce build times, this action automatically identifies the best layer cache to pull from your container registry.
It falls back gracefully in the following order:

1. The `latest` tag.
2. The immediately preceding SemVer tag (if bumping or providing a new version).
3. The most recently created tag in the registry.

## SemVer Alias Tags

When the tag matches a semantic versioning pattern, the action automatically creates and pushes additional alias tags:

| Tag format | Primary tag | Alias tags created |
| --- | --- | --- |
| `vX.Y.Z` (e.g. `v1.2.3`) | `v1.2.3` | `v1.2`, `v1` |
| `{prefix}-vX.Y.Z` (e.g. `main-v1.2.3`) | `main-v1.2.3` | `main-v1.2`, `main-v1` |
| Any other format (e.g. `latest`) | as-is | *(none)* |

This allows callers to pin to a specific patch (`v1.2.3`), minor (`v1.2`), or major (`v1`) version.

## Version Progression Check

When the image tag is a SemVer tag and the registry is `ghcr.io`, the action queries the registry for existing image versions and verifies that the new version is exactly **one major, minor, or patch increment** ahead of the previous one. This prevents accidental large version jumps or downgrades.

The check is automatically **skipped** when:

* The tag is not a SemVer tag (e.g., `latest`).
* No previous image exists in the registry yet.
* The registry is not `ghcr.io`.

Set `version_force: 'true'` to bypass the check entirely.

## Examples

### Bump version automatically

You can tell the action to automatically calculate the next version based on existing Git tags. *Note: Ensure your `actions/checkout` step uses `fetch-depth: 0` so the action can see previous tags.*

```yaml
      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          bump_type: 'patch' # Will increment v1.2.3 to v1.2.4

```

### Manual trigger with an exact version

```yaml
      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          version: 'v2.0.0'

```

### Custom image name

```yaml
      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          image_name: 'ghcr.io/myorg/my-devcontainer'

```

### Non-default devcontainer path

```yaml
      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          devcontainer_path: 'src/.devcontainer'

```

### Using a non-GitHub container registry

When using a custom `image_name`, the `registry` input is only used for login—it is not automatically prepended to the image name. Ensure they match.

```yaml
      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.REGISTRY_TOKEN }}
          registry: 'registry.example.com'
          registry_username: 'my-username'
          image_name: '[registry.example.com/myorg/my-devcontainer](https://registry.example.com/myorg/my-devcontainer)'
```

## Smart Metadata Injection (`zzz-build-info`)

This Action features native integration with the `ghcr.io/MiguelRodo/DevContainerFeatures/zzz-build-info` devcontainer feature.

When `inject_build_info` is `true` (the default), the Action safely parses your `.devcontainer/devcontainer.json`.
If it detects that you have included the `zzz-build-info` feature, it temporarily injects the dynamically calculated `imageVersion` into the configuration directly prior to the build.

This provides the command `/usr/local/bin/container-info` inside the container, which outputs the build details in this format:

```text
--------------------------------------------------
🚀 DevContainer Release Information
--------------------------------------------------
Version: v1.2.3
Built On: 2026-06-12T14:36:22Z
--------------------------------------------------
```

Note that the devcontainer.json file is reverted to its state when the imageVersion option was not injected, immediately after the build.

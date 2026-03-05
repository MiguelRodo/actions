# Pre-build Dev Container Action

**Pre-build Dev Container** is a composite GitHub Action that speeds up Dev Container startup times. It builds your `.devcontainer/Dockerfile`, tags it with a git tag (and automatically creates SemVer alias tags), pushes it to a container registry, and optionally generates a `prebuild/devcontainer.json` for instant loads.

## Quick Start

Copy this into `.github/workflows/prebuild-devcontainer.yml`:

```yaml
name: 'Pre-build Dev Container'

on:
  push:
    tags:
      - 'v*'
      - '*-v*'
  workflow_dispatch:
    inputs:
      tag:
        description: 'Tag to build (e.g. v1.2.3 or main-v1.2.3)'
        required: true

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

      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          tag: ${{ github.event.inputs.tag }}
```

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `github_token` | Token for logging into the container registry and pushing commits. | **Yes** | — |
| `no_cache` | Disable Docker cache during build (`true`/`false`). | No | `false` |
| `create_prebuild_json` | Generate and commit a `prebuild/devcontainer.json` (`true`/`false`). | No | `true` |
| `devcontainer_path` | Path to the `.devcontainer` directory, relative to the repo root. | No | `.devcontainer` |
| `image_name` | Full image name without tag (e.g. `ghcr.io/myorg/myimage`). Defaults to `{registry}/{repo}-{branch}` where `{branch}` is the current branch name (e.g. `ghcr.io/owner/myrepo-main`). The branch name is always used for the image name even when tagging with SemVer. | No | `{registry}/{repo}-{branch}` |
| `tag` | Git tag used as the primary container image tag (e.g. `v1.2.3` or `main-v1.2.3`). Auto-detected from `GITHUB_REF` on tag push. Falls back to `latest` if not set and not a tag push. | No | `""` |
| `registry` | Container registry URL. | No | `ghcr.io` |
| `registry_username` | Username for registry login. | No | Repository owner |

## SemVer Alias Tags

When the tag matches a semantic versioning pattern, the action automatically creates and pushes additional alias tags:

| Tag format | Primary tag | Alias tags created |
| --- | --- | --- |
| `vX.Y.Z` (e.g. `v1.2.3`) | `v1.2.3` | `v1.2`, `v1` |
| `{prefix}-vX.Y.Z` (e.g. `main-v1.2.3`) | `main-v1.2.3` | `main-v1.2`, `main-v1` |
| Any other format (e.g. `latest`) | as-is | _(none)_ |

This allows callers to pin to a specific patch (`v1.2.3`), minor (`v1.2`), or major (`v1`) version.

## Examples

### Standard tag push workflow

Trigger automatically when a tag like `v1.2.3` or `main-v1.2.3` is pushed:

```yaml
on:
  push:
    tags:
      - 'v*'
      - '*-v*'
```

### Manual trigger with a custom tag

```yaml
      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          tag: ${{ github.event.inputs.tag }}
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
          image_name: 'registry.example.com/myorg/my-devcontainer'
```

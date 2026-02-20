# Pre-build Dev Container Action

**Pre-build Dev Container** is a composite GitHub Action that speeds up Dev Container startup times. It builds your `.devcontainer/Dockerfile`, tags it with a unique commit SHA (or `latest`), pushes it to a container registry, and optionally generates a `prebuild/devcontainer.json` for instant loads.

## Quick Start

Copy this into `.github/workflows/prebuild-devcontainer.yml`:

```yaml
name: 'Pre-build Dev Container'

on:
  push:
    branches:
      - 'main'
    paths:
      - '.devcontainer/**'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@main
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `github_token` | Token for logging into the container registry and pushing commits. | **Yes** | — |
| `no_cache` | Disable Docker cache during build (`true`/`false`). | No | `false` |
| `create_prebuild_json` | Generate and commit a `prebuild/devcontainer.json` (`true`/`false`). | No | `true` |
| `devcontainer_path` | Path to the `.devcontainer` directory, relative to the repo root. | No | `.devcontainer` |
| `image_name` | Full image name without tag (e.g. `ghcr.io/myorg/myimage`). | No | `{registry}/{repo}-{branch}` |
| `append_sha` | Append the Git short SHA as the image tag. If `false`, uses `latest`. | No | `true` |
| `registry` | Container registry URL. | No | `ghcr.io` |
| `registry_username` | Username for registry login. | No | Repository owner |

## Examples

### Custom image name without SHA tag

```yaml
      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@main
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          image_name: 'ghcr.io/myorg/my-devcontainer'
          append_sha: 'false'
```

### Non-default devcontainer path

```yaml
      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@main
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          devcontainer_path: 'src/.devcontainer'
```

### Using a non-GitHub container registry

```yaml
      - name: Run Dev Container Prebuild
        uses: MiguelRodo/actions/prebuild-devcontainer@main
        with:
          github_token: ${{ secrets.REGISTRY_TOKEN }}
          registry: 'registry.example.com'
          registry_username: 'my-username'
          image_name: 'registry.example.com/myorg/my-devcontainer'
```
# Custom GitHub Actions

Reusable composite GitHub Actions for Dev Container deployment and issue tracking.

## Actions

### [Pre-build Dev Container](./prebuild-devcontainer)

Builds your Dev Container, pushes it to a container registry (GHCR by default, or any registry you configure), and optionally generates a `prebuild/devcontainer.json` for instant loads.

Copy the following to `.github/workflows/prebuild-devcontainer.yml`:

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

See the [action README](./prebuild-devcontainer/README.md) for all inputs, including how to set a custom image name, use a non-default devcontainer path, disable SHA tagging, or use a non-GitHub container registry.

### [Add Issues to Project](./add-issues-to-project)

Syncs issues from a repository to a GitHub Project (V2) board with duplicate detection.

**Requires:** A Personal Access Token (PAT) with `repo`, `project`, and `read:org` (if applicable) scopes, saved as the `ADD_ISSUES_TO_PROJECT_TOKEN` secret.

Copy the following to `.github/workflows/add-issues-to-project.yml`:

```yaml
name: Sync Issues to Project

on:
  workflow_dispatch:
  issues:
    types: [opened, reopened]

jobs:
  add-to-project:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Add Issues to Project
        uses: MiguelRodo/actions/add-issues-to-project@main
        with:
          ADD_ISSUES_TO_PROJECT_TOKEN: ${{ secrets.ADD_ISSUES_TO_PROJECT_TOKEN }}
          # Optional overrides:
          # project_name: "My Custom Project Board"
          # is_project_owner_org: "true"
```

See the [action README](./add-issues-to-project/README.md) for all inputs and advanced usage.

## Usage

Reference actions directly in your workflow files—no cloning required:

```yaml
uses: MiguelRodo/actions/<action-folder-name>@main
```
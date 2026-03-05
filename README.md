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
        uses: MiguelRodo/actions/add-issues-to-project@v2
        with:
          ADD_ISSUES_TO_PROJECT_TOKEN: ${{ secrets.ADD_ISSUES_TO_PROJECT_TOKEN }}
          # Optional overrides:
          # project_name: "My Custom Project Board"
          # is_project_owner_org: "true"
```

See the [action README](./add-issues-to-project/README.md) for all inputs and advanced usage.

## Releasing a New Version

This repository uses an automated release workflow (`.github/workflows/release.yml`) to handle version bumping, floating tag updates, and GitHub Release creation.

### How to release

**Option 1 — Push a tag directly:**

```bash
git tag v1.2.3
git push origin v1.2.3
```

The workflow triggers automatically on any tag matching `vX.Y.Z`.

**Option 2 — Run the workflow manually:**

Go to **Actions → Publish Release and Bump Floating Tags → Run workflow**, enter the version (e.g. `v1.2.3`), and click **Run workflow**.

### What the workflow does

1. Validates that the version matches the strict `vX.Y.Z` semantic format.
2. (Manual mode only) Creates and pushes the base tag (e.g. `v1.2.3`) if it does not already exist.
3. Force-updates the floating major (`v1`) and minor (`v1.2`) tags to point to the new commit.
4. Creates a GitHub Release for the specific version with auto-generated release notes and marks it as the latest release.

## Usage

Reference actions directly in your workflow files—no cloning required:

```yaml
uses: MiguelRodo/actions/<action-folder-name>@main
```

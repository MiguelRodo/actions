# Custom GitHub Actions

A centralized collection of custom, reusable composite GitHub Actions built to automate repository management, issue tracking, and Dev Container deployments.

## 🚀 Available Actions

### 1. [Pre-build Dev Container](./prebuild-devcontainer)

Automates the compilation and deployment of VS Code Dev Containers. Builds your Dockerfile, tags it dynamically with a unique commit SHA to bypass local caching issues, pushes it to GHCR, and generates a pre-built JSON configuration for instant loads.

To use it, add the following to `.github/workflows/prebuild-devcontainer.yml` in your repo:

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
          no_cache: 'false'
          create_prebuild_json: 'true'
  ```

### [Add Issues to Project](./add-issues-to-project)

Automates the synchronization between a repository's issues and a GitHub Project (V2) board. It safely fetches issues, checks the target board to prevent duplicates, and appends new issues automatically. Supports cross-repository syncing and organization-owned project boards.

* **Usage path:** `MiguelRodo/actions/add-issues-to-project@main`
* **Requires:** A Personal Access Token (PAT) with `project` and `repo` scopes, named `Add_ISSUES_TO_PROJECT_TOKEN`.

To use, dd the following to `.github/workflows/add-issues-to-project.yml` in your repo:

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

## 🛠️ General Usage

To use any of these actions in your own repositories, you don't need to clone or copy the code. Simply reference the action directory in your workflow file.

Example:

```yaml
steps:
  - name: Checkout repository
    uses: actions/checkout@v4

  - name: Run a custom action
    uses: MiguelRodo/actions/<action-folder-name>@main
    with:
      # Action-specific inputs go here
```

For detailed setup instructions, input variables, and permission requirements, please refer to the README.md located inside each action's respective folder.
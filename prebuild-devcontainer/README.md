Here are the two `README.md` files.

The first is the comprehensive guide to live inside your `prebuild-devcontainer` folder, complete with the specific troubleshooting steps for the permission error. The second is a clean, centralized directory for the root of your `actions` repository.

### 1. The Action-Specific README (`prebuild-devcontainer/README.md`)

```markdown
# Pre-build Dev Container Action

![GitHub Marketplace](https://img.shields.io/badge/Marketplace-GitHub%20Action-blue)

**Pre-build Dev Container** is a composite GitHub Action designed to dramatically speed up your Dev Container startup times. It automatically builds your `.devcontainer/Dockerfile`, tags it with a unique Git commit SHA to bust local Docker caches, pushes it to the GitHub Container Registry (GHCR), and optionally updates a secondary `prebuild/devcontainer.json` file for instant remote loading.

## 📋 TL;DR

To quickly set up the pre-build action:

1. **Copy the workflow template** below.
2. **Paste it** into your repository's `.github/workflows/` directory (e.g., `.github/workflows/prebuild.yml`).
3. **Run the workflow** manually or wait for a push to `main` that modifies your dev container configuration.

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

---

## 📖 Table of Contents

* [🔍 Description](https://www.google.com/search?q=%23-description)
* [🔧 Inputs](https://www.google.com/search?q=%23-inputs)
* [🐞 Troubleshooting](https://www.google.com/search?q=%23-troubleshooting)

---

## 🔍 Description

When dealing with complex Dev Containers (like those requiring extensive `apt` packages or heavy R/Python environments), building from scratch locally can take ages.

This action solves that by running the build process in GitHub Actions and outputting a pre-compiled image. By automatically rewriting your `devcontainer.json` to point to this immutable, SHA-tagged image, developers can launch the environment in seconds without worrying about stale local Docker caches.

---

## 🔧 Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `github_token` | GitHub token for logging into GHCR and pushing commits. Usually `${{ secrets.GITHUB_TOKEN }}`. | Yes | — |
| `no_cache` | Disable Docker cache during the build phase (`true`/`false`). Useful if upstream dependencies changed but your Dockerfile didn't. | No | `false` |
| `create_prebuild_json` | Generate, commit, and push the `.devcontainer/prebuild/devcontainer.json` file back to the repository (`true`/`false`). | No | `true` |

---

## 🐞 Troubleshooting

### ❌ GITHUB ACTIONS PERMISSION ERROR

If you have `create_prebuild_json: 'true'`, this action needs to commit the updated JSON file back to your repository. If the build succeeds but fails on the final `git push` step, it is a permissions issue.

By default, GitHub Actions lack write permissions to commit back to the repository.

**🛠️ HOW TO FIX THIS:**

1. Go to your repository on GitHub.
2. Click **Settings** -> **Actions** -> **General**.
3. Scroll down to **Workflow permissions**.
4. Change the selection to **Read and write permissions**.
5. Click **Save** and re-run this workflow.

```

---

### 2. The Root Repository README (`README.md` at the root of `MiguelRodo/actions`)

```markdown
# Custom GitHub Actions

A centralized collection of custom, reusable composite GitHub Actions built to automate repository management, issue tracking, and Dev Container deployments.

## 🚀 Available Actions

### 1. [Pre-build Dev Container](./prebuild-devcontainer)
Automates the compilation and deployment of VS Code Dev Containers. Builds your Dockerfile, tags it dynamically with a unique commit SHA to bypass local caching issues, pushes it to GHCR, and generates a pre-built JSON configuration for instant loads.

* **Usage path:** `MiguelRodo/actions/prebuild-devcontainer@main`

### 2. [Add Issues to Project](./add-issues-to-project)
Automates the process of fetching all issues from a specified repository and adding them to a designated GitHub Project. Includes duplication checks to keep your project boards clean and organized.

* **Usage path:** `MiguelRodo/actions/add-issues-to-project@main`

---

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

For detailed setup instructions, input variables, and permission requirements, please refer to the `README.md` located inside each action's respective folder.

```

Would you like me to help write a quick bash script you can run to automatically initialize this folder structure, create the files, and commit it to your repo?

```
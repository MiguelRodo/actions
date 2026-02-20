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
For detailed setup instructions, input variables, and permission requirements, please refer to the README.md located inside each action's respective folder.
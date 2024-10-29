# Add Issues to Project GitHub Action

![GitHub Marketplace](https://img.shields.io/badge/Marketplace-GitHub%20Action-blue)

**Add Issues to Project** is a GitHub Action that automates the process of adding issues from a specified repository to a designated GitHub Project. It ensures that each issue is only added once, preventing duplicates and keeping your project organized.

## 📋 TL;DR

To quickly set up the **Add Issues to Project** action:

1. **Copy the workflow template** below.
2. **Paste it** into your repository's `.github/workflows/` directory (e.g., `.github/workflows/add-issues-to-project.yml`).
3. **Create repository token** with projects acccess:
    - *Generate a token*:
        - Go to https://github.com/settings/tokens/new
        - Select `repo`, `project` and `read:org` scopes.
        - Click `Generate token` and copy token.
    - *Save token* as a repository secret:
        - Go to https://github.com/<user_name>/<repo_name>/settings/secrets/actions
        - Click `New repository secret`, paste copied token and name it `ADD_ISSUES_TO_PROJECT_TOKEN`.
3. **Configure the inputs** as needed.
    - By default, it assumes that the project's name and owner are the same as the repo. Typically, you will at least change the project name.
4. **Run the workflow** manually from the GitHub Actions tab.

```yaml
name: Add Issues to Project

on:
  workflow_dispatch:
    inputs:
      project_name:
        description: "Project name."
        default: "PhD"
        required: false
      project_owner:
        description: "Project owner. Defaults to repository owner."
        required: false
      is_project_owner_org:
        description: "Whether the project owner is an organization. Defaults to `false`."
        required: false
        default: "false"
      source_repo_name:
        description: "Repository name. Defaults to current repository."
        required: false
      source_repo_owner:
        description: "Repository owner. Defaults to current GitHub user."
        required: false

jobs:
  add-issues-to-project:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Add Issues to Project Action
        uses: MiguelRodo/actions/add-issues-to-project@v1.0.16
        with:
          project_name: ${{ github.event.inputs.project_name }}
          project_owner: ${{ github.event.inputs.project_owner }}
          is_project_owner_org: ${{ github.event.inputs.is_project_owner_org }}
          source_repo_name: ${{ github.event.inputs.source_repo_name }}
          source_repo_owner: ${{ github.event.inputs.source_repo_owner }}
          ADD_ISSUES_TO_PROJECT_TOKEN: ${{ secrets.ADD_ISSUES_TO_PROJECT_TOKEN }}
```

---

## 📖 Table of Contents

- [Add Issues to Project GitHub Action](#add-issues-to-project-github-action)
  - [📋 TL;DR](#-tldr)
  - [📖 Table of Contents](#-table-of-contents)
  - [🔍 Description](#-description)
  - [⚙️ Prerequisites](#️-prerequisites)
  - [🔧 Inputs](#-inputs)
  - [🚀 Usage](#-usage)
    - [1. Create or Obtain a Personal Access Token (PAT)](#1-create-or-obtain-a-personal-access-token-pat)
    - [2. Store the PAT as a Secret](#2-store-the-pat-as-a-secret)
    - [3. Set Up the Workflow](#3-set-up-the-workflow)
    - [4. Trigger the Workflow](#4-trigger-the-workflow)
  - [🛠️ Example](#️-example)
  - [❓ Notes](#-notes)
  - [🐞 Troubleshooting](#-troubleshooting)
  - [📄 License](#-license)
  - [🙌 Acknowledgments](#-acknowledgments)

---

## 🔍 Description

The **Add Issues to Project** action streamlines the management of your GitHub Projects by:

- **Fetching all issues** from a specified repository.
- **Checking for existing issues** in the project to avoid duplicates.
- **Adding new issues** to the project seamlessly.

Whether you're managing a personal project or an organizational one, this action adapts to your needs with flexible input options.

---

## ⚙️ Prerequisites

- **Personal Access Token (PAT):** Ensure you have a GitHub PAT with the following scopes:
  - `repo`
  - `read:org`
  - `project`

  Store this token securely as a secret in your repository or organization settings (e.g., `ADD_ISSUES_TO_PROJECT_TOKEN`).

---

## 🔧 Inputs

| Input                  | Description                                                                                      | Required | Default            |
| ---------------------- | ------------------------------------------------------------------------------------------------ | -------- | ------------------ |
| `project_name`         | Name of the GitHub Project to which issues should be added. Defaults to repository name.        | No       | Repository Name    |
| `project_owner`        | Owner of the GitHub Project. Defaults to repository owner.                                      | No       | Repository Owner   |
| `is_project_owner_org` | Indicates if the project owner is an organization. Defaults to `false`.                         | No       | `false`            |
| `source_repo_name`     | Name of the source repository. Defaults to the current repository.                              | No       | Current Repository |
| `source_repo_owner`    | Owner of the source repository. Defaults to the current GitHub user.                            | No       | Current User       |
| `ADD_ISSUES_TO_PROJECT_TOKEN` | GitHub token with correct access for accessing issues and writing to projects.                | Yes      | —                  |

---

## 🚀 Usage

### 1. Create or Obtain a Personal Access Token (PAT)

If you need to create a new PAT:

1. Go to [GitHub Settings](https://github.com/settings/tokens).
2. Click on **Generate new token**.
3. Select the scopes:
   - `repo`
   - `read:org`
   - `project`
4. Click **Generate token** and copy the token.

### 2. Store the PAT as a Secret

Add the PAT to your repository secrets:

1. Navigate to your repository on GitHub.
2. Go to **Settings** > **Secrets and variables** > **Actions**.
3. Click **New repository secret**.
4. Name it `ADD_ISSUES_TO_PROJECT_TOKEN` and paste your PAT.

### 3. Set Up the Workflow

Create a workflow file in your repository (e.g., `.github/workflows/add-issues-to-project.yml`) using the TL;DR template provided above.

### 4. Trigger the Workflow

You can manually trigger the workflow:

1. Go to the **Actions** tab in your repository.
2. Select **Add Issues to Project** workflow.
3. Click **Run workflow**, fill in the required inputs, and start the workflow.

---

## 🛠️ Example

Here's an example configuration for adding issues to a project named "Awesome Project" owned by an organization:

```yaml
name: Add Issues to Project

on:
  workflow_dispatch:
    inputs:
      project_name:
        description: "Project name."
        default: "Awesome Project"
        required: false
      project_owner:
        description: "Project owner. Defaults to repository owner."
        required: false
      is_project_owner_org:
        description: "Whether the project owner is an organization. Defaults to `false`."
        required: false
        default: "true"
      source_repo_name:
        description: "Repository name. Defaults to current repository."
        required: false
      source_repo_owner:
        description: "Repository owner. Defaults to current GitHub user."
        required: false

jobs:
  add-issues-to-project:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Add Issues to Project Action
        uses: MiguelRodo/actions/add-issues-to-project@v1.1.0
        with:
          project_name: ${{ github.event.inputs.project_name }}
          project_owner: ${{ github.event.inputs.project_owner }}
          is_project_owner_org: ${{ github.event.inputs.is_project_owner_org }}
          source_repo_name: ${{ github.event.inputs.source_repo_name }}
          source_repo_owner: ${{ github.event.inputs.source_repo_owner }}
          ADD_ISSUES_TO_PROJECT_TOKEN: ${{ secrets.ADD_ISSUES_TO_PROJECT_TOKEN }}
```

---

## ❓ Notes

- **GitHub CLI and jq:** The action installs the GitHub CLI (`gh`) and `jq` during runtime to interact with GitHub's API.
- **Authentication:** The action unsets any existing `GH_TOKEN` or `GITHUB_TOKEN` to ensure it uses your provided `ADD_ISSUES_TO_PROJECT_TOKEN`.
- **Existing Issues:** The action checks for existing issues in the project to avoid duplicates.
- **Organization Projects:** If you're adding issues to an organization project, set `is_project_owner_org` to `true`.

---

## 🐞 Troubleshooting

- **Authentication Errors:** Ensure your `ADD_ISSUES_TO_PROJECT_TOKEN` has the correct scopes and is stored correctly as a secret.
- **Project Not Found:** Verify that the `project_name` and `project_owner` are correct and that the project exists.
- **Permission Issues:** Make sure the PAT has access to the organization and the project.
- **Invalid Repository Format:** Ensure the `source_repo` follows the `owner/repo` format.

---

## 📄 License

This project is licensed under the terms of the [MIT License](LICENSE).

---

## 🙌 Acknowledgments

Developed by [Miguel Rodo](https://github.com/MiguelRodo) (and extensive ChatGPT). Inspired by [SATVILab](https://github.com/SATVILab). Contributions and feedback are welcome!

---

**Feel free to contribute or raise issues for any problems you encounter.**
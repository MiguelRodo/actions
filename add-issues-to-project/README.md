# Add Issues to Project Action

![GitHub Marketplace](https://img.shields.io/badge/Marketplace-GitHub%20Action-blue)

**Add Issues to Project** is a composite GitHub Action that automates the process of fetching issues from a specified repository and adding them to a designated GitHub Project (V2). It features built-in duplicate detection, ensuring issues are only added once, keeping your project boards clean and organized.

## 📋 TL;DR

To quickly set up this action in your repository:

1. **Generate a Personal Access Token (PAT)** with `repo`, `project`, and `read:org` (if applicable) scopes.
2. **Save the PAT** as a repository secret named `ADD_ISSUES_TO_PROJECT_TOKEN`.
3. **Create a workflow file** (e.g., `.github/workflows/sync-issues.yml`) using the template below.

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

---

## 📖 Table of Contents

* [🔧 Inputs](https://www.google.com/search?q=%23-inputs)
* [⚙️ How It Works](https://www.google.com/search?q=%23%EF%B8%8F-how-it-works)
* [🛠️ Advanced Example](https://www.google.com/search?q=%23%EF%B8%8F-advanced-example)
* [🐞 Troubleshooting](https://www.google.com/search?q=%23-troubleshooting)

---

## 🔧 Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `ADD_ISSUES_TO_PROJECT_TOKEN` | A GitHub PAT with permissions to read the source repository and write to the target GitHub Project. | **Yes** | — |
| `project_name` | The name of the target GitHub Project. | No | *Current Repository Name* |
| `project_owner` | The username or organization that owns the target project. | No | *Current Repository Owner* |
| `is_project_owner_org` | Set to `"true"` if the project owner is a GitHub Organization. | No | `"false"` |
| `source_repo_name` | The name of the repository to pull issues from. | No | *Current Repository Name* |
| `source_repo_owner` | The owner of the source repository. | No | *Current GitHub User* |

---

## ⚙️ How It Works

Under the hood, this action:

1. Installs the GitHub CLI (`gh`) and the `gh-projects` extension.
2. Authenticates using your provided `ADD_ISSUES_TO_PROJECT_TOKEN` (bypassing the default, lower-permission `GITHUB_TOKEN`).
3. Validates that the target project, organization/user, and source repository actually exist.
4. Uses GraphQL to fetch the target Project ID and paginate through all existing items on the board.
5. Cross-references the board's existing issue IDs against the repository's issue list.
6. Appends only the *missing* issues to the project via a GraphQL mutation.

---

## 🛠️ Advanced Example

If you want to sync issues from a repository into a centrally managed Organization project board with a different name:

```yaml
      - name: Add Issues to Central Org Project
        uses: MiguelRodo/actions/add-issues-to-project@main
        with:
          ADD_ISSUES_TO_PROJECT_TOKEN: ${{ secrets.ORG_PROJECT_PAT }}
          project_name: "Q1 Engineering Roadmap"
          project_owner: "MyAwesomeOrg"
          is_project_owner_org: "true"
          source_repo_name: "frontend-client"
          source_repo_owner: "MyAwesomeOrg"

```

---

## 🐞 Troubleshooting

* **Action fails at authentication:** Ensure your `ADD_ISSUES_TO_PROJECT_TOKEN` is active, has not expired, and contains the `project` scope. Classic PATs are often easier to configure for organization-wide project boards than fine-grained tokens.
* **Project Not Found:** Double-check your spelling for `project_name`. If the project belongs to an organization rather than your personal user account, you *must* set `is_project_owner_org: "true"`.

```

# Add Issues to Project GitHub Action

This GitHub Action adds all issues from a repository to a specified GitHub Project. It checks for existing issues in the project to prevent duplicates.

## Description

The **Add Issues to Project** action automates the process of adding all open issues from your repository to a specified GitHub Project. It:

- Fetches all issues from the repository.
- Checks if each issue is already in the project.
- Adds the issue to the project if it's not already included.

## Prerequisites

- **Personal Access Token (PAT):** You need a GitHub PAT with the following scopes:
  - `repo`
  - `read:org`
  - `project`

  Store this token securely as a secret in your repository or organization settings (e.g., `ADD_ISSUES_TO_PROJECT_TOKEN`).


## Inputs

- **`project_name`** (required): The name of the GitHub Project to which issues should be added.
- **`org_name`** (optional): The name of the organization if the project is an organization project. Defaults to `SATVILab`.
- **`ADD_ISSUES_TO_PROJECT_TOKEN`** (required): The GitHub token with access to issues and projects.

## Usage

### 1. Create or Obtain a Personal Access Token (PAT)

*Note*: for SATVI members, an organisation secret named `ADD_ISSUES_TO_PROJECT_TOKEN` is already set and will automatically be available for repos on `SATVILab`:

- steps 1 and 2 may be skipped, and
- step 3 already has the correct name for the secret.

Generate a PAT with the necessary scopes:

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

Create a workflow file in your repository (e.g., `.github/workflows/add-issues-to-project.yml`):

```yaml
name: Add Issues to Project

on:
  workflow_dispatch:
    inputs:
      project_name:
        description: 'Name of the project'
        required: true
        default: 'Your Project Name'
      org_name:
        description: 'Organization name (if project is an organization project)'
        required: false
        default: SATVILab

jobs:
  add-issues-to-project:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Add Issues to Project Action
        with:
          project_name: ${{ github.event.inputs.project_name }}
          org_name: ${{ github.event.inputs.org_name }}
        env:
          ADD_ISSUES_TO_PROJECT_TOKEN: ${{ secrets.ADD_ISSUES_TO_PROJECT_TOKEN }}
        uses: SATVILab/actions/add-issues-to-project@v1.0.4

```

### 4. Trigger the Workflow

You can manually trigger the workflow:

1. Go to the **Actions** tab in your repository.
2. Select **Add Issues to Project** workflow.
3. Click **Run workflow**, fill in the required inputs, and start the workflow.

## Notes

- **GitHub CLI and jq:** The action installs the GitHub CLI (`gh`) and `jq` during runtime to interact with GitHub's API.
- **Authentication:** The action unsets any existing `GH_TOKEN` or `GITHUB_TOKEN` to ensure it uses your provided `ADD_ISSUES_TO_PROJECT_TOKEN`.
- **Existing Issues:** The action checks for existing issues in the project to avoid duplicates.
- **Organization Projects:** If you're adding issues to an organization project, ensure you provide the `org_name`.

## Example

Here's how you might configure the action for a project named "Awesome Project" in your organization:

```yaml
name: Add Issues to Project

on:
  workflow_dispatch:
    inputs:
      project_name:
        description: 'Name of the project'
        required: true
        default: 'Awesome Project'
      org_name:
        description: 'Organization name (if project is an organization project)'
        required: false
        default: YourOrganizationName

jobs:
  add-issues-to-project:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Add Issues to Project Action
        with:
          project_name: ${{ github.event.inputs.project_name }}
          org_name: ${{ github.event.inputs.org_name }}
        env:
          ADD_ISSUES_TO_PROJECT_TOKEN: ${{ secrets.ADD_ISSUES_TO_PROJECT_TOKEN }}
        uses: SATVILab/actions/add-issues-to-project@v1.0.3

```

## Troubleshooting

- **Authentication Errors:** Ensure your `ADD_ISSUES_TO_PROJECT_TOKEN` has the correct scopes and is stored correctly as a secret.
- **Project Not Found:** Verify that the `project_name` and `org_name` are correct and that the project exists.
- **Permission Issues:** Make sure the PAT has access to the organization and the project.

## License

This project is licensed under the terms of the MIT license.

## Acknowledgments

Developed by [SATVI](https://github.com/SATVILab). Feel free to contribute or raise issues for any problems you encounter.

# Setup Project Infrastructure

Bootstraps new multi-repo workspaces by linking the working repository, container build pipelines, package caches, and tracking logic automatically.

This action acts as a comprehensive scaffold for research projects or compendiums, cloning boilerplate structures, cross-linking container builds to a central registry, injecting continuous deployment GitHub Actions workflows, generating `repos.list` files for the `setupmjr` suite, and executing workspace provisioning entirely downstream.

## Usage

```yaml
name: Bootstrap Project Environment

on:
  workflow_dispatch:

jobs:
  bootstrap:
    runs-on: ubuntu-latest
    steps:
      - uses: MiguelRodo/actions/setup-project-infrastructure@v2
        with:
          working_repo: "owner/target-compendium@main"
          template_repo: "owner/template-repo@main"
          builder_repo: "owner/devcontainer-builds@target-compendium"
          gh_token: ${{ secrets.PAT_TOKEN }}
```

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `working_repo` | The primary coding/compendium repository and target branch we are setting up (e.g., `owner/repo@branch`). | Yes | |
| `template_repo` | The base template source supplying the boilerplate `.devcontainer/` layout. | Yes | |
| `builder_repo` | The repository designated to compile the Docker image and host it on GHCR. | No | Defaults to `working_repo` |
| `config_repo` | The destination repository where the active workspace `devcontainer.json` will be written. | No | Defaults to `working_repo` |
| `renv_pkgs` | Semicolon/comma-separated list of standalone R packages to inject into the renv-cache feature. | No | |
| `renv_repos` | Semicolon/comma-separated list of lockfile repositories to cache via the renv-cache feature. | No | |
| `repos_list` | Semicolon/comma-separated list of external sub-repositories/branches to track. | No | |
| `gh_token` | A Classic PAT (or write-scoped Fine-Grained PAT) with write access across all involved repositories. | Yes | |

## Outputs

*   Branches automatically created or updated.
*   `.devcontainer/` folders populated or redirected to GHCR.
*   `repos.list` generated and tracked.
*   `.github/workflows/devcontainer-build.yml` injected dynamically into remote builders.
*   Job summary details written out to GitHub Actions UI.

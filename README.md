# Custom GitHub Actions

Reusable composite GitHub Actions for common CI/CD tasks: pre-building Dev Containers, syncing issues to GitHub Projects, automating version bumps and releases, and publishing Quarto sites.

> **Full documentation:** [https://miguelrodo.github.io/actions](https://miguelrodo.github.io/actions)

## Actions

### [Pre-build Dev Container](./prebuild-devcontainer)

Builds your Dev Container image, pushes it to a container registry (GHCR by default), and optionally generates a `prebuild/devcontainer.json` for instant environment loads.

<details>
<summary>Minimal workflow</summary>

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
      - uses: actions/checkout@v4
      - uses: MiguelRodo/actions/prebuild-devcontainer@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          tag: ${{ github.event.inputs.tag }}
```

</details>

See the [action README](./prebuild-devcontainer/README.md) for all inputs, including custom image names, non-default devcontainer paths, and alternative container registries.

---

### [Add Issues to Project](./add-issues-to-project)

Syncs issues from a repository to a GitHub Project (V2) board with built-in duplicate detection.

**Requires:** A PAT with `repo`, `project`, and `read:org` scopes saved as the `ADD_ISSUES_TO_PROJECT_TOKEN` secret.

<details>
<summary>Minimal workflow</summary>

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
      - uses: actions/checkout@v4
      - uses: MiguelRodo/actions/add-issues-to-project@v2
        with:
          ADD_ISSUES_TO_PROJECT_TOKEN: ${{ secrets.ADD_ISSUES_TO_PROJECT_TOKEN }}
          # project_name: "My Custom Project Board"
          # is_project_owner_org: "true"
```

</details>

See the [action README](./add-issues-to-project/README.md) for all inputs and advanced usage.

---

### [Version and Release](./version-release)

Bumps versions in Python (`pyproject.toml`) and/or R (`DESCRIPTION`) packages, creates a versioned git tag with floating major/minor aliases, and publishes a GitHub Release.

<details>
<summary>Minimal workflow</summary>

```yaml
name: Version and Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'
  workflow_dispatch:
    inputs:
      version:
        description: 'Exact version (e.g. 1.2.3). Cannot be used with bump_type.'
        required: false
      bump_type:
        description: 'Component to bump: major | minor | patch. Cannot be used with version.'
        required: false
      python_version:
        description: 'Override: exact version for the Python package.'
        required: false
      r_version:
        description: 'Override: exact version for the R package.'
        required: false

jobs:
  version-release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: MiguelRodo/actions/version-release@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          version: ${{ inputs.version }}
          bump_type: ${{ inputs.bump_type }}
          python_version: ${{ inputs.python_version }}
          r_version: ${{ inputs.r_version }}
```

</details>

See the [action README](./version-release/README.md) for all inputs, outputs, and version-precedence rules.

---

### [Publish Quarto Site](./publish-quarto-site)

Publishes a Quarto site to the `gh-pages` branch, creating the branch automatically if it does not already exist.

<details>
<summary>Minimal workflow</summary>

```yaml
name: Publish Quarto Site

on:
  push:
    branches: [main]

permissions:
  contents: write
  pages: write

jobs:
  build-and-publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: MiguelRodo/actions/publish-quarto-site@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

</details>

See the [action README](./publish-quarto-site/README.md) for all inputs and troubleshooting tips.

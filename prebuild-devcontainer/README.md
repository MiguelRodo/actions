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
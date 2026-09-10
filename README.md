# Custom GitHub Actions

Reusable composite GitHub Actions for common CI/CD, release, repository and development-environment tasks.

## Available actions

<!-- action-catalogue:start -->
<!-- Generated from */action.yml by scripts/generate-action-docs.py. Do not edit this block manually. -->
| Action | Description |
| --- | --- |
| [Add Issues to Project](./add-issues-to-project/README.md) | Adds issues from a specified repository to a specified GitHub Project. |
| [Prune APT Repository](./apt-repo-prune/README.md) | Removes superseded .deb package versions from a GitHub-hosted apt repository and rewrites Git history so that the pruned binaries are fully eliminated. After history rewrite the apt metadata (Packages, Release, optional InRelease / Release.gpg) is regenerated and the result is force-pushed. |
| [Go Version and Release](./go-version-release/README.md) | Determines a Go project release version, validates semver progression, creates and pushes a git tag, then runs GoReleaser and can publish generated .deb artifacts to apt. |
| [Pre-build Dev Container](./prebuild-devcontainer/README.md) | Builds a devcontainer, pushes it to a container registry tagged with a git tag and SemVer aliases, and optionally updates the prebuild JSON. |
| [Publish Quarto Site](./publish-quarto-site/README.md) | Publishes a Quarto site to the gh-pages branch, creating the branch if it does not already exist. |
| [R Version and Release](./r-version-release/README.md) | Bumps the version in DESCRIPTION, builds the R package, pushes floating tags, and publishes a GitHub Release with the tarball. |
| [Rust Version and Release](./rust-version-release/README.md) | Determines a Rust project release version, validates semver progression, creates and pushes a git tag, then builds .deb with cargo-deb and can publish generated .deb artifacts to apt. |
| [Setup Project Infrastructure](./setup-project-infrastructure/README.md) | Bootstraps new multi-repo workspaces by linking working repo, devcontainers, caches, and tracking. |
| [Version and Release](./version-release/README.md) | Bumps versions for Python (pyproject.toml) and R (DESCRIPTION) packages when present, creates a versioned git tag, updates floating major/minor tags, and publishes a GitHub Release. |
<!-- action-catalogue:end -->

## Usage

Reference an action directly from a workflow:

```yaml
uses: MiguelRodo/actions/<action-folder-name>@v2
```

Use a specific `vX.Y.Z` tag when you want an exact release, or pin a full commit SHA for the strongest supply-chain reproducibility.

## Documentation

Each action's README contains its usage, permissions and operational guidance. The published documentation site is available at <https://miguelrodo.github.io/actions/>.

Input/output reference tables and this catalogue are generated from the corresponding `action.yml` metadata. Regenerate them after changing an action interface:

```bash
python3 scripts/generate-action-docs.py --write
```

CI verifies that generated documentation is current with:

```bash
python3 scripts/generate-action-docs.py --check
```

Only the bounded `action-inputs`, `action-outputs` and `action-catalogue` blocks are generated. Narrative guidance and examples outside those blocks remain hand-written.

## Releases

Repository releases are managed by `.github/workflows/release.yml`. Specific release tags use `vX.Y.Z`; floating `vX` and `vX.Y` tags follow the latest compatible release.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and documentation guidance.

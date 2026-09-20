# Go Version and Release Action

Standalone composite action for pure Go releases. It resolves a semantic version, optionally validates strict progression from the latest semver tag, creates/pushes the release tag, updates floating major/minor tags, runs GoReleaser for native publishing (GitHub Releases/Homebrew/Scoop via `.goreleaser.yml`), and can also publish generated `.deb` artifacts to a separate GitHub repository as a structured apt repository.

## Usage

Copy the following to `.github/workflows/go-version-release.yml`:

```yaml
name: Go Version and Release

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Exact release version in X.Y.Z form (e.g. 1.2.3). Leave blank to bump a component.'
        required: false
        type: string
      bump_type:
        description: 'Component to bump. Choose none when entering an exact version.'
        required: false
        type: choice
        default: none
        options:
          - none
          - patch
          - minor
          - major
      version_force:
        description: 'Allow a non-sequential version, such as a downgrade or skipped increment.'
        required: false
        type: boolean
        default: false
      go_version:
        description: 'Go version to install (e.g. 1.27).'
        required: false
        type: string
        default: '1.27'
      goreleaser_config:
        description: 'GoReleaser config path (e.g. .goreleaser.yml).'
        required: false
        type: string
        default: '.goreleaser.yml'
      apt_repo:
        description: 'APT target repository as owner/name; leave blank to skip APT publishing.'
        required: false
        type: string

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: MiguelRodo/actions/go-version-release@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          apt_repo_token: ${{ secrets.APT_REPO_TOKEN }}
          apt_signing_key: ${{ secrets.APT_SIGNING_KEY }}
          apt_signing_key_passphrase: ${{ secrets.APT_SIGNING_KEY_PASSPHRASE }}
          scoop_token: ${{ secrets.SCOOP_TAP_TOKEN }}
          homebrew_token: ${{ secrets.HOMEBREW_TAP_TOKEN }}
          version: ${{ inputs.version }}
          bump_type: ${{ inputs.bump_type != 'none' && inputs.bump_type || '' }}
          version_force: ${{ inputs.version_force }}
          go_version: ${{ inputs.go_version }}
          goreleaser_config: ${{ inputs.goreleaser_config }}
          apt_repo: ${{ inputs.apt_repo }}
```

> [!IMPORTANT]
> Use `fetch-depth: 0` on checkout so the action can inspect existing tags.
>
> This action currently supports Linux runners only. Use a Linux runner such as `ubuntu-latest`.

<!-- action-inputs:start -->
<!-- Generated from go-version-release/action.yml by scripts/generate-action-docs.py. Do not edit this block manually. -->
## Inputs

| Input | Description | Required | Default |
| --- | --- | :---: | --- |
| `github_token` | GitHub token for pushing tags and publishing releases. | Yes | — |
| `apt_repo_token` | Token with write access to apt_repo; defaults to github_token. | No | `""` |
| `apt_signing_key` | ASCII-armoured GPG private key for signing APT metadata; leave blank for unsigned metadata. | No | `""` |
| `apt_signing_key_passphrase` | Passphrase for apt_signing_key; leave blank for an unencrypted key. | No | `""` |
| `version` | Exact release version in X.Y.Z form (e.g. 1.2.3). Leave blank to use bump_type. | No | `""` |
| `bump_type` | Version component to bump: patch, minor, or major. Leave blank when version is set. | No | `""` |
| `version_force` | Set true to allow non-sequential versions (e.g. downgrades or skipped increments). | No | `false` |
| `go_version` | Go version to install (e.g. 1.27). | No | `1.27` |
| `apt_repo` | APT target repository as owner/name; leave blank to skip APT publishing. | No | `""` |
| `goreleaser_config` | Path to the GoReleaser config file (e.g. .goreleaser.yml). | No | `.goreleaser.yml` |
| `scoop_token` | Token for publishing Scoop manifests to an external repository. | No | `""` |
| `homebrew_token` | Token for publishing Homebrew formulae to an external repository. | No | `""` |
<!-- action-inputs:end -->

<!-- action-outputs:start -->
<!-- Generated from go-version-release/action.yml by scripts/generate-action-docs.py. Do not edit this block manually. -->
## Outputs

| Output | Description |
| --- | --- |
| `version` | Released version without a leading v (e.g. 1.2.3). |
| `tag` | Git tag that was created or reused (e.g. v1.2.3). |
<!-- action-outputs:end -->

## Version resolution

- If `bump_type` is provided, the action computes the next version from the latest
  semver tag using `scripts/apply-version-bump.sh`.
- If `version` is provided, it is used directly (after stripping optional leading `v`).
- If neither is provided, tag-triggered workflows use `github.ref_name`.
- If both are provided, the action fails.

## Version progression guard

By default the action validates the new version against the latest previous semver tag using `scripts/check-version-progression.sh`. Set `version_force: true` to skip that guard and allow a non-sequential version.

## Tag behavior

The action creates or reuses the release tag `vX.Y.Z` and also updates floating tags:

- `vX`
- `vX.Y`

For example, releasing `v1.2.3` updates `v1` and `v1.2` to point to the same commit.

The action works for both:

- tag-driven workflows (`push.tags`, where the tag name becomes the release version)
- manual `workflow_dispatch` runs (where you provide `version` or `bump_type`)

The composite action is intended to run on Linux GitHub Actions runners. It validates `runner.os == Linux` before continuing because its release asset collection and APT publishing steps rely on Linux/GNU tooling.

## Release assets

GoReleaser is run with `release --clean --skip=announce`, so GoReleaser natively handles publishing GitHub Releases plus optional Homebrew and Scoop targets configured in your `.goreleaser.yml`.

This action still relies on GoReleaser output in `dist/` for apt publishing, so you should continue generating `.deb` artifacts with GoReleaser `nfpms`.

To publish Homebrew and Scoop, define native GoReleaser `brews:` and `scoops:` blocks in your `.goreleaser.yml`, and pass the required tokens.

### Recommended GoReleaser outputs

To satisfy downstream consumers and apt publication, configure GoReleaser to emit:

- Linux `tar.gz` archives for each supported architecture (for example `amd64`, `arm64`)
- macOS `tar.gz` archives
- Windows `zip` archives
- `.deb` packages for each Debian target architecture you support
- a checksum manifest (for example `checksums.txt` or `SHA256SUMS`)

Example asset names typically look like:

- `myapp_1.2.3_linux_amd64.tar.gz`
- `myapp_1.2.3_darwin_arm64.tar.gz`
- `myapp_1.2.3_windows_amd64.zip`
- `myapp_1.2.3_linux_amd64.deb`
- `checksums.txt`

One way to produce those artifacts is with a GoReleaser config that defines `builds`, `archives`, `nfpms`, and `checksums`.

## Optional apt publishing

When `apt_repo` is set, the action:

1. Finds generated `.deb` artifacts in `dist/`
2. Clones the target repository's `main` branch
3. Publishes `.deb` files under `pool/main/<bucket>/`
4. Regenerates architecture-specific `Packages` / `Packages.gz` indexes in `dists/stable/main/binary-<arch>/`
5. Regenerates `dists/stable/Release` with all detected architectures
6. When `apt_signing_key` is provided, signs the `Release` file to produce `dists/stable/InRelease` (clearsigned) and `Release.gpg` (detached ASCII-armoured signature)
7. Commits and pushes the updated apt repository contents

The same `.deb` files remain attached to the GitHub Release as downloadable assets.

Notes:

- `github_token` is used for tag/release/current-repository operations.
- For `apt_repo` clone/push operations, the action uses `apt_repo_token` when provided; otherwise it falls back to `github_token`.
- For the initial target repository described in this repo, set `apt_repo` to `MiguelRodo/apt-miguelrodo`.
- When `apt_signing_key` is omitted, the action publishes only the unsigned `Release` file and removes any stale `InRelease` / `Release.gpg`. Use this mode for repositories that do not require signature verification.
- The public key published as `KEY.gpg` in the apt repository must match the private key supplied via `apt_signing_key`. To extract the public key from your private key and commit it to the apt repository, run:
  ```sh
  gpg --export --armor <FINGERPRINT> > KEY.gpg
  ```
  where `<FINGERPRINT>` is the fingerprint of your signing key. Users should install the key into a scoped keyring and reference it with `signed-by=` in their apt source entry:
  ```sh
  # Install the repository public key (scoped — only trusted for this repo)
  sudo install -dm755 /etc/apt/keyrings
  gpg --dearmor < KEY.gpg | sudo tee /etc/apt/keyrings/myrepo.gpg > /dev/null
  ```
  Then add the source with `signed-by=` in `/etc/apt/sources.list.d/myrepo.list`:
  ```
  deb [signed-by=/etc/apt/keyrings/myrepo.gpg] https://<apt-repo-url> stable main
  ```
  This limits trust to this specific repository and avoids adding the key as globally trusted (as would be the case with `/etc/apt/trusted.gpg.d/`).

## Why use this action vs `goreleaser/goreleaser-action`?

This action adds release workflow capabilities around GoReleaser:

- **Version management:** resolves explicit or bumped semver versions and can enforce strict progression.
- **Floating tags:** automatically updates `vX` and `vX.Y` aliases alongside `vX.Y.Z`.
- **APT repository management:** publishes `.deb` artifacts to a full apt repository layout and can sign metadata (`Release`, `InRelease`, `Release.gpg`) with GPG.

Use GoReleaser config (`.goreleaser.yml`) for native publishers such as GitHub Releases, Homebrew, and Scoop.

# Go Version and Release Action

Standalone composite action for pure Go releases. It resolves a semantic version, optionally validates strict progression from the latest semver tag, creates/pushes the release tag, updates floating major/minor tags, runs GoReleaser to build packaged multiplatform artifacts, uploads those artifacts to the GitHub Release for the tag, and can also publish generated `.deb` artifacts to a separate GitHub repository as a structured apt repository.

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
        description: 'Exact version (e.g. 1.2.3). Cannot be used with bump_type.'
        required: false
      bump_type:
        description: 'Component to bump: major | minor | patch. Cannot be used with version.'
        required: false
      version_check:
        description: 'Run strict version progression checks (true/false).'
        required: false
      go_version:
        description: 'Go version to install.'
        required: false
      goreleaser_config:
        description: 'Optional path to the GoReleaser config file.'
        required: false
      apt_repo:
        description: 'Optional target GitHub repository in owner/name form for publishing generated .deb artifacts.'
        required: false
      apt_repo_token:
        description: 'Optional token for apt_repo access when publishing to a different repository.'
        required: false
      scoop_repo:
        description: 'Optional target GitHub repository in owner/name form for publishing a Scoop manifest file.'
        required: false
      scoop_manifest_source:
        description: 'Optional path to the Scoop manifest source file.'
        required: false
      scoop_manifest_path:
        description: 'Optional destination path in scoop_repo (defaults to bucket/<manifest>.json).'
        required: false
      homebrew_tap:
        description: 'Optional target GitHub repository in owner/name form for publishing a Homebrew formula file.'
        required: false
      homebrew_formula_source:
        description: 'Optional path to the Homebrew formula source file.'
        required: false
      homebrew_formula_path:
        description: 'Optional destination path in homebrew_tap (defaults to Formula/<formula>.rb).'
        required: false
      apt_signing_key:
        description: 'Optional ASCII-armored GPG private key for signing apt repository metadata.'
        required: false

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: MiguelRodo/actions/go-version-release@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          apt_repo_token: ${{ secrets.APT_REPO_TOKEN }}
          apt_signing_key: ${{ secrets.APT_SIGNING_KEY }}
          apt_signing_key_passphrase: ${{ secrets.APT_SIGNING_KEY_PASSPHRASE }}
          version: ${{ inputs.version }}
          bump_type: ${{ inputs.bump_type }}
          version_check: ${{ inputs.version_check }}
          go_version: ${{ inputs.go_version }}
          goreleaser_config: ${{ inputs.goreleaser_config }}
          apt_repo: ${{ inputs.apt_repo }}
          scoop_repo: ${{ inputs.scoop_repo }}
          scoop_manifest_source: ${{ inputs.scoop_manifest_source }}
          scoop_manifest_path: ${{ inputs.scoop_manifest_path }}
          homebrew_tap: ${{ inputs.homebrew_tap }}
          homebrew_formula_source: ${{ inputs.homebrew_formula_source }}
          homebrew_formula_path: ${{ inputs.homebrew_formula_path }}
```

> [!IMPORTANT]
> Use `fetch-depth: 0` on checkout so the action can inspect existing tags.
>
> This action currently supports Linux runners only. Use a Linux runner such as `ubuntu-latest`.

## Inputs

| Input | Description | Required |
|---|---|---|
| `github_token` | GitHub token for pushing tags and publishing releases. | **Yes** |
| `version` | Exact version (e.g. `1.2.3`). Cannot be used with `bump_type`. | No |
| `bump_type` | Version component to bump: `major`, `minor`, or `patch`. Cannot be used with `version`. | No |
| `version_check` | When `true` (default), enforce strict progression from latest semver tag. | No |
| `go_version` | Go version for `actions/setup-go` (default `1.22`). | No |
| `goreleaser_config` | Path to the GoReleaser configuration file (default `.goreleaser.yml`). | No |
| `apt_repo` | Optional GitHub repository in `owner/name` form. When set, generated `.deb` artifacts from `dist/` are published to that repo's `main` branch using a structured apt layout (`pool/` and `dists/stable/main/binary-*`). | No |
| `apt_repo_token` | Optional token used only for `apt_repo` clone/push operations. If omitted, the action falls back to `github_token`. | No |
| `scoop_repo` | Optional GitHub repository in `owner/name` form. When set, the action publishes a Scoop manifest file from the current workflow workspace into that repository's `main` branch. | No |
| `scoop_repo_token` | Optional token used only for `scoop_repo` clone/push operations. If omitted, the action falls back to `github_token`. | No |
| `scoop_manifest_source` | Optional source path to the Scoop manifest file (relative to workspace or absolute). If omitted and `scoop_repo` is set, the action auto-detects exactly one `*.json` file in `dist/`. | No |
| `scoop_manifest_path` | Optional destination path inside `scoop_repo`. Defaults to `bucket/<manifest-filename>.json`. | No |
| `homebrew_tap` | Optional GitHub repository in `owner/name` form. When set, the action publishes a Homebrew formula file from the current workflow workspace into that repository's `main` branch. | No |
| `homebrew_tap_token` | Optional token used only for `homebrew_tap` clone/push operations. If omitted, the action falls back to `github_token`. | No |
| `homebrew_formula_source` | Optional source path to the Homebrew formula file (relative to workspace or absolute). If omitted and `homebrew_tap` is set, the action auto-detects exactly one `*.rb` file in `dist/`. | No |
| `homebrew_formula_path` | Optional destination path inside `homebrew_tap`. Defaults to `Formula/<formula-filename>.rb`. | No |
| `apt_signing_key` | Optional ASCII-armored GPG private key for signing apt repository metadata. When set, the action imports the key and generates signed `InRelease` and `Release.gpg` files alongside `Release`. Store this as a GitHub secret (e.g. `APT_SIGNING_KEY`). | No |
| `apt_signing_key_passphrase` | Optional passphrase for `apt_signing_key`. When set, GPG uses it via `--passphrase-file` (written to a secure temp file) so passphrase-protected private keys work. Store as a GitHub secret (e.g. `APT_SIGNING_KEY_PASSPHRASE`). | No |

## Outputs

| Output | Description |
|---|---|
| `version` | Released version without leading `v` (e.g. `1.2.3`). |
| `tag` | Released git tag with leading `v` (e.g. `v1.2.3`). |

## Version resolution

- If `bump_type` is provided, the action computes the next version from the latest
  semver tag using `scripts/apply-version-bump.sh`.
- If `version` is provided, it is used directly (after stripping optional leading `v`).
- If neither is provided, tag-triggered workflows use `github.ref_name`.
- If both are provided, the action fails.

## Version progression guard

When `version_check: true`, the action validates the new version against the latest
previous semver tag using `scripts/check-version-progression.sh`.

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

GoReleaser is run with `release --clean --skip=publish --skip=announce`, so it is responsible for building release packages in `dist/`, while this action is responsible for creating/updating the GitHub Release and attaching the packaged artifacts it finds there.

The action uploads every packaged release file in `dist/` that matches these categories:

- Linux and macOS archives: `*.tar.gz`
- Windows archives: `*.zip`
- Debian packages: `*.deb`
- Checksum manifests such as `checksums.txt`, `SHA256SUMS`, or similar names containing `checksums` / `sha256sum`

At least one checksum file must exist or the action fails.

### Recommended GoReleaser outputs

To satisfy the release-asset expectations for downstream consumers such as Homebrew, Scoop, and direct downloads, configure GoReleaser to emit:

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
6. When `apt_signing_key` is provided, signs the `Release` file to produce `dists/stable/InRelease` (clearsigned) and `dists/stable/Release.gpg` (detached ASCII-armored signature)
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

## Optional Scoop publishing

When `scoop_repo` is set, the action:

1. Resolves the Scoop manifest source file:
   - `scoop_manifest_source` when provided, otherwise
   - exactly one `*.json` found in `dist/`
2. Clones the target `scoop_repo` repository `main` branch
3. Copies the manifest to:
   - `scoop_manifest_path` when provided, otherwise
   - `bucket/<manifest-filename>.json`
4. Commits and pushes the change (if any)

## Optional Homebrew tap publishing

When `homebrew_tap` is set, the action:

1. Resolves the Homebrew formula source file:
   - `homebrew_formula_source` when provided, otherwise
   - exactly one `*.rb` found in `dist/`
2. Clones the target `homebrew_tap` repository `main` branch
3. Copies the formula to:
   - `homebrew_formula_path` when provided, otherwise
   - `Formula/<formula-filename>.rb`
4. Commits and pushes the change (if any)

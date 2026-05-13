# APT Repository Prune Action

Composite action for pruning superseded `.deb` package versions from a GitHub-hosted apt repository.  The action rewrites the full Git history of the target repository so that removed binaries are eliminated entirely—not just from the tip—then regenerates the apt metadata and force-pushes the result.

The action is designed for repositories that are managed by the [go-version-release](../go-version-release) action in this repository; it validates the expected `pool/main/` and `dists/stable/` structure before proceeding.

> [!IMPORTANT]
> Because history is rewritten every run requires a **force-push**.  Ensure the target repository's `main` branch does **not** have force-push protection enabled (or that the token used has bypass permission).
>
> This action supports **Linux runners only**.  Use `ubuntu-latest` or another Linux runner.

## Usage

```yaml
name: Prune APT Repository

on:
  workflow_dispatch:
    inputs:
      retention:
        description: 'Retention policy: latest | latest-patch-per-minor | latest-minor-per-major'
        required: false
        default: latest-minor-per-major
  schedule:
    - cron: '0 3 * * 0'   # weekly on Sunday at 03:00 UTC

jobs:
  prune:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: MiguelRodo/actions/apt-repo-prune@v2
        with:
          repo: myorg/my-apt-repo
          token: ${{ secrets.APT_REPO_TOKEN }}
          retention: ${{ inputs.retention || 'latest-minor-per-major' }}
          apt_signing_key: ${{ secrets.APT_SIGNING_KEY }}
          apt_signing_key_passphrase: ${{ secrets.APT_SIGNING_KEY_PASSPHRASE }}
```

## Inputs

| Input | Description | Required | Default |
|---|---|---|---|
| `repo` | Target apt repository in `owner/name` form. | **Yes** | — |
| `token` | GitHub token with `contents:write` permission on the target repository. | **Yes** | — |
| `retention` | Version retention policy (see below). | No | `latest-minor-per-major` |
| `apt_signing_key` | ASCII-armored GPG private key for signing regenerated apt metadata. When omitted, only the unsigned `Release` file is written and any stale `InRelease` / `Release.gpg` files are removed. | No | `""` |
| `apt_signing_key_passphrase` | Passphrase for `apt_signing_key`. | No | `""` |

### Retention policies

| Policy | What is kept |
|---|---|
| `latest` | The single most-recent version across all packages and series. |
| `latest-patch-per-minor` | The highest patch release for each `MAJOR.MINOR` series (e.g. keeps `1.0.5`, `1.1.3`, `2.0.1` but removes `1.0.4`, `1.1.2`). |
| `latest-minor-per-major` | The highest `MINOR.PATCH` release for each `MAJOR` series (e.g. keeps `1.2.3` and `2.1.0` but removes `1.1.5`, `1.2.2`). **This is the default.** |

The policy is applied independently per `(package-name, architecture)` pair so that each arch is pruned consistently.

## How it works

1. **Clone** – The target repository is cloned with its full history.
2. **Validate structure** – The action checks that `pool/main/` and `dists/stable/` exist (the layout produced by `go-version-release`).
3. **Select files to remove** – `scripts/apt-prune-select-versions.sh` reads every `.deb` file via `dpkg-deb`, groups versions by `(package, arch)`, and outputs the relative paths of files that fall outside the retention window.
4. **Rewrite history** – [`git filter-repo`](https://github.com/newren/git-filter-repo) removes the selected files from every commit.  The root commit is only rewritten when it contains one of the target files; otherwise its SHA is preserved.
5. **Regenerate metadata** – `Packages`, `Packages.gz`, and `Release` are rebuilt from the remaining `.deb` files.  When `apt_signing_key` is supplied, `InRelease` (clearsigned) and `Release.gpg` (detached signature) are also regenerated.
6. **Force-push** – The rewritten history is pushed to `origin/main` with `--force`.

## Notes

- The action requires `dpkg-deb`, `dpkg-scanpackages`, and `apt-ftparchive` to be available on the runner.  These are pre-installed on `ubuntu-latest`.
- `git-filter-repo` is installed automatically via `pip` if it is not already present.
- Only `.deb` files with plain `X.Y.Z` semver versions are considered; files with non-semver versions are left untouched.
- Each package architecture is evaluated independently, so you can have `amd64` at version `2.1.0` while `arm64` is still at `2.0.0` and both will be treated separately.

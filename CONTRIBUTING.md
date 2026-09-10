# Contributing

Thank you for considering a contribution to this repository! All improvements — bug fixes, documentation, new features, and tests — are welcome.

## Getting started

1. **Fork** the repository and create a feature branch from `main`.
2. Make your changes following the guidelines below.
3. Open a **pull request** against `main` with a clear description of what changed and why.

## Development guidelines

### Composite actions

Each action lives in its own subdirectory (e.g. `prebuild-devcontainer/`). The entry point is always `action.yml`.

- Keep all logic inside `action.yml`. Avoid adding separate shell scripts unless the complexity makes inline scripts unreadable.
- Use `$GITHUB_OUTPUT` (not `::set-output`) for outputs and `$GITHUB_ENV` for inter-step environment variables.
- Every new input must have a `description` and a `required` field. Provide a `default` for optional inputs.
- Every new output must be declared in the `outputs:` block of `action.yml`.

### Shell scripts

Inline `run:` blocks are linted by **actionlint** (which delegates to **shellcheck**). Before submitting:

- Ensure your scripts pass `shellcheck --shell=bash`.
- Prefer `[[ ... ]]` over `[ ... ]` for conditionals in bash.
- Quote all variable expansions (e.g. `"$VAR"`) unless word-splitting is intentional.

### Documentation

- Each action has its own `README.md` containing hand-written usage, permissions and operational guidance.
- `action.yml` is the canonical source for an action's machine-readable name, description, inputs and outputs.
- After changing that metadata, regenerate the reference tables and action catalogues with:

  ```bash
  python3 scripts/generate-action-docs.py --write
  ```

- Do not hand-edit content inside `action-inputs`, `action-outputs` or `action-catalogue` marker blocks. CI runs `python3 scripts/generate-action-docs.py --check` and fails when those sections are stale.
- Keep narrative guidance and examples outside generated blocks up to date when behaviour changes.
- The root `README.md` is intentionally a concise catalogue rather than a second copy of each action's documentation.
- Complete, copy-paste-ready workflow files live in the `examples/` directory.

### Workflow dependency security

Repository-owned workflows under `.github/workflows/` may receive privileged tokens, publish artifacts or enforce CI. Their third-party actions are therefore pinned to full immutable commit SHAs, with the corresponding release version retained as an inline comment. Dependabot updates these SHA pins monthly and groups routine GitHub Actions updates into one low-noise PR; updates still require the normal protected-branch CI before merge.

Published composite actions and copy-paste consumer examples may instead use readable major tags such as `@v2`. Those surfaces prioritize consumer compatibility and automatic patch uptake, while this repository's own privileged execution path uses stricter immutable pins.

`actionlint` is installed by `scripts/install-actionlint.sh` from a fixed release archive whose SHA-256 digest is pinned to the checksum published with that upstream release. It is updated manually when needed rather than through a separate recurring version-check workflow.

### Releases

Releases are managed by `.github/workflows/publish-release.yml`. Release requests use a `repository_dispatch` event so GitHub always loads the privileged workflow from the default branch, never from the commit being tagged.

Request a release with a token that can dispatch repository events:

```bash
gh api --method POST repos/MiguelRodo/actions/dispatches --input - <<'JSON'
{"event_type":"release","client_payload":{"version":"vX.Y.Z"}}
JSON
```

#### Release guards

The workflow refuses to release a commit that is not on `main`:

- Only `repository_dispatch` with event type `release` triggers publishing. Direct tag pushes do not trigger the trusted workflow.
- The checked-out release commit is the default-branch SHA associated with the dispatch event and must be **reachable from `origin/main`** (`scripts/check-release-ancestry.sh`).
- All required checks must have **succeeded for that exact commit** (`scripts/check-required-ci.sh`) before any tag is moved: actionlint/shellcheck, BATS, and the prebuild-devcontainer integration test.
- An existing version tag is reusable only when it resolves to the validated release commit (`scripts/check-release-tag.sh`).
- Floating `vX` / `vX.Y` tags are updated **last**, only after ancestry, CI status and release creation have all passed, and are pinned to the validated commit.

The one-time `.github/workflows/disable-legacy-release.yml` migration disables the historical `.github/workflows/release.yml` workflow identity after this change reaches `main`. This prevents a tag pointing at an older commit from executing that commit's obsolete tag-push workflow.

#### Tag vs. Release

- **Specific tags** (`vX.Y.Z`) are annotated tags and have an associated GitHub Release entry with auto-generated notes.
- **Floating tags** (`vX`, `vX.Y`) are lightweight tags that are force-updated on every release to point to the latest matching commit. They do **not** have their own GitHub Release entries — this is intentional. The GitHub Releases page only shows entries for specific `vX.Y.Z` tags.
- Consumers of these actions should pin to a floating tag (e.g. `@v2` or `@v2.17`) or a specific tag (e.g. `@v2.17.0`), not to a Release object.

To verify what commit a floating tag resolves to:

```bash
# Show the commit a tag points to
git ls-remote --tags https://github.com/MiguelRodo/actions "refs/tags/v2"
# or, in a local clone:
git rev-list -n 1 refs/tags/v2
```

## Code of conduct

Please be respectful and constructive in all interactions. This project follows the [Contributor Covenant](https://www.contributor-covenant.org/) code of conduct.

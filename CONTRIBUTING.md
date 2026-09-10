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

### Releases

Releases are managed by the `.github/workflows/release.yml` workflow. Tags **must** originate from the `main` branch and follow the `vX.Y.Z` format.

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

# Copilot instructions for `MiguelRodo/actions`

This repository contains **reusable composite GitHub Actions** plus shared bash
scripts. There is no compiled application: everything is YAML and bash.

## Layout

- `<action-name>/action.yml` — the entry point for each composite action, with
  `<action-name>/README.md` documenting inputs, outputs and permissions.
- `scripts/*.sh` — shared bash helpers called from actions via
  `$GITHUB_ACTION_PATH/../scripts/...`.
- `scripts/tests/*.bats` — BATS tests, including tests that assert on the
  contents of `action.yml` files (e.g. pinned action versions and defaults).
- `examples/` — copy-paste-ready caller workflows.
- `*.qmd` and `_quarto.yml` — the published documentation site; each
  `<action>.qmd` mirrors `<action>/README.md`.

## Validation (run these before finishing)

```bash
actionlint                                     # workflows + composite action inline run blocks
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -r shellcheck
bats scripts/tests/
```

These are exactly the checks run by `.github/workflows/ci.yml`, and the tools
are preinstalled by `.github/workflows/copilot-setup-steps.yml`.

## Conventions

- Keep logic inside `action.yml`; only factor out to `scripts/` when inline
  scripts become unreadable, and add BATS coverage when you do.
- Use `$GITHUB_OUTPUT` and `$GITHUB_ENV`, never `::set-output`.
- Every input needs `description` and `required`; optional inputs need a
  `default`. Every output must be declared and documented.
- Bash: prefer `[[ ... ]]`, quote expansions, and keep scripts shellcheck-clean.
- Pin third-party and official actions to a major tag (e.g. `actions/checkout@v6`).
- When a version, default or pinned action tag changes in an `action.yml`,
  update the matching assertion in `scripts/tests/` **and** the action README,
  the matching `.qmd`, and the root `README.md`.

## Do not

- Do not create or move git tags; releases are handled by
  `.github/workflows/release.yml` from `main`.
- Do not add new linters, test frameworks or dependencies without a clear need.
- Do not commit secrets or tokens; pass them as action inputs.

# Copilot instructions for `MiguelRodo/actions`

This repository contains **reusable composite GitHub Actions** plus shared bash
scripts. There is no compiled application: everything is YAML and bash.

## Layout

- `<action-name>/action.yml` — the entry point for each composite action and the
  canonical source for machine-readable action name, description, inputs and outputs.
- `<action-name>/README.md` — hand-written usage and operational guidance with
  bounded generated input/output reference blocks.
- `scripts/*.sh` — shared bash helpers called from actions via
  `$GITHUB_ACTION_PATH/../scripts/...`.
- `scripts/tests/*.bats` — BATS tests, including tests that assert on the
  contents of `action.yml` files (e.g. pinned action versions and defaults).
- `examples/` — copy-paste-ready caller workflows.
- `*.qmd` and `_quarto.yml` — the published documentation site; action pages
  retain hand-written site guidance while their input/output references are generated.

## Validation (run these before finishing)

```bash
actionlint                                     # workflows + composite action inline run blocks
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -r shellcheck
python3 scripts/generate-action-docs.py --check
bats scripts/tests/
```

These are the checks run by `.github/workflows/ci.yml`, and the shell tools are
preinstalled by `.github/workflows/copilot-setup-steps.yml`.

## Conventions

- Keep logic inside `action.yml`; only factor out to `scripts/` when inline
  scripts become unreadable, and add BATS coverage when you do.
- Use `$GITHUB_OUTPUT` and `$GITHUB_ENV`, never `::set-output`.
- Every input needs `description` and `required`; optional inputs need a
  `default`. Every output must be declared in `action.yml`.
- Bash: prefer `[[ ... ]]`, quote expansions, and keep scripts shellcheck-clean.
- Pin third-party and official actions to a major tag (e.g. `actions/checkout@v6`).
- After changing an action's `name`, `description`, inputs or outputs, run
  `python3 scripts/generate-action-docs.py --write`. Do not hand-edit content
  inside `action-inputs`, `action-outputs` or `action-catalogue` marker blocks.
- Update hand-written README/QMD guidance and examples when behaviour changes;
  generated reference tables are not a substitute for conceptual documentation.

## Do not

- Do not create or move git tags; releases are handled by
  `.github/workflows/release.yml` from `main`.
- Do not add new linters, test frameworks or dependencies without a clear need.
- Do not commit secrets or tokens; pass them as action inputs.

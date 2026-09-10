#!/usr/bin/env python3
"""Generate action reference documentation from composite action metadata.

The public input/output contract lives in each ``<action>/action.yml``.  This
script keeps bounded reference sections in the action README and matching
Quarto page in sync, and generates the repository-level action catalogues.

Use ``--write`` to update files and ``--check`` in CI to fail when generated
content is stale.  The parser intentionally handles only the small, regular
metadata subset used before ``runs:`` in composite action files, so the script
has no third-party Python dependencies.
"""

from __future__ import annotations

import argparse
import ast
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


INPUT_START = "<!-- action-inputs:start -->"
INPUT_END = "<!-- action-inputs:end -->"
OUTPUT_START = "<!-- action-outputs:start -->"
OUTPUT_END = "<!-- action-outputs:end -->"
CATALOGUE_START = "<!-- action-catalogue:start -->"
CATALOGUE_END = "<!-- action-catalogue:end -->"
GENERATED_QMD_MARKER = "<!-- generated-from-action-readme -->"


@dataclass
class Field:
    name: str
    description: str = ""
    required: bool = False
    default: str | None = None


@dataclass
class Action:
    slug: str
    name: str
    description: str
    inputs: list[Field] = field(default_factory=list)
    outputs: list[Field] = field(default_factory=list)


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1].replace("''", "'")
    if len(value) >= 2 and value[0] == value[-1] == '"':
        try:
            parsed = ast.literal_eval(value)
            if isinstance(parsed, str):
                return parsed
        except (SyntaxError, ValueError):
            pass
        return value[1:-1]
    return value


def folded_block(lines: list[str], start: int, parent_indent: int) -> tuple[str, int]:
    """Read a YAML block scalar as compact prose and return (value, next index)."""
    parts: list[str] = []
    i = start
    while i < len(lines):
        line = lines[i]
        if line.strip() and indent_of(line) <= parent_indent:
            break
        if line.strip():
            parts.append(line.strip())
        i += 1
    return " ".join(parts), i


def scalar_or_block(
    lines: list[str], index: int, raw: str, field_indent: int
) -> tuple[str, int]:
    raw = raw.strip()
    if raw.startswith(">") or raw.startswith("|"):
        return folded_block(lines, index + 1, field_indent)
    return unquote(raw), index + 1


def top_scalar(lines: list[str], key: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}:\s*(.*)$")
    for i, line in enumerate(lines):
        match = pattern.match(line)
        if not match:
            continue
        value, _ = scalar_or_block(lines, i, match.group(1), 0)
        return value
    return ""


def parse_mapping_section(lines: list[str], section: str) -> list[Field]:
    start = None
    for i, line in enumerate(lines):
        if line == f"{section}:":
            start = i + 1
            break
    if start is None:
        return []

    result: list[Field] = []
    i = start
    while i < len(lines):
        line = lines[i]
        if line.strip() and indent_of(line) == 0:
            break
        item = re.match(r"^  ([A-Za-z0-9_.-]+):\s*$", line)
        if not item:
            i += 1
            continue

        current = Field(name=item.group(1))
        i += 1
        while i < len(lines):
            line = lines[i]
            if not line.strip():
                i += 1
                continue
            level = indent_of(line)
            if level <= 2:
                break
            child = re.match(r"^    ([A-Za-z0-9_.-]+):\s*(.*)$", line)
            if not child:
                i += 1
                continue
            key, raw = child.groups()
            value, next_i = scalar_or_block(lines, i, raw, 4)
            if key == "description":
                current.description = value
            elif key == "required":
                current.required = value.lower() == "true"
            elif key == "default":
                current.default = value
            i = next_i
        result.append(current)
    return result


def parse_action(path: Path) -> Action:
    lines = path.read_text(encoding="utf-8").splitlines()
    name = top_scalar(lines, "name") or path.parent.name
    return Action(
        slug=path.parent.name,
        name=name,
        description=top_scalar(lines, "description"),
        inputs=parse_mapping_section(lines, "inputs"),
        outputs=parse_mapping_section(lines, "outputs"),
    )


def escape_cell(value: str) -> str:
    return value.replace("|", r"\|").replace("\n", "<br>")


def default_cell(value: str | None) -> str:
    if value is None:
        return "—"
    rendered = '""' if value == "" else value
    rendered = rendered.replace("`", r"\`")
    return escape_cell(f"`{rendered}`")


def reference_table(fields: Iterable[Field], kind: str) -> str:
    fields = list(fields)
    if kind == "inputs":
        lines = [
            "| Input | Description | Required | Default |",
            "| --- | --- | :---: | --- |",
        ]
        for item in fields:
            lines.append(
                f"| `{item.name}` | {escape_cell(item.description)} | "
                f"{'Yes' if item.required else 'No'} | {default_cell(item.default)} |"
            )
    else:
        lines = ["| Output | Description |", "| --- | --- |"]
        for item in fields:
            lines.append(f"| `{item.name}` | {escape_cell(item.description)} |")
    return "\n".join(lines)


def marker_pair(kind: str) -> tuple[str, str]:
    if kind == "inputs":
        return INPUT_START, INPUT_END
    return OUTPUT_START, OUTPUT_END


def heading_pattern(kind: str) -> re.Pattern[str]:
    return re.compile(rf"^##\s+.*\b{kind}\b.*$", re.IGNORECASE | re.MULTILINE)


def render_reference_block(action: Action, kind: str, heading: str) -> str:
    start, end = marker_pair(kind)
    fields = action.inputs if kind == "inputs" else action.outputs
    source = f"{action.slug}/action.yml"
    return (
        f"{start}\n"
        f"<!-- Generated from {source} by scripts/generate-action-docs.py. Do not edit this block manually. -->\n"
        f"{heading}\n\n"
        f"{reference_table(fields, kind)}\n"
        f"{end}"
    )


def replace_reference_section(text: str, action: Action, kind: str) -> str:
    fields = action.inputs if kind == "inputs" else action.outputs
    if not fields:
        return text

    start_marker, end_marker = marker_pair(kind)
    marker_start = text.find(start_marker)
    marker_end = text.find(end_marker)
    heading = None

    if marker_start != -1 and marker_end != -1 and marker_end > marker_start:
        marker_end += len(end_marker)
        existing = text[marker_start:marker_end]
        match = heading_pattern(kind).search(existing)
        heading = match.group(0) if match else f"## {kind.title()}"
        block = render_reference_block(action, kind, heading)
        return text[:marker_start] + block + text[marker_end:]

    match = heading_pattern(kind).search(text)
    if match:
        heading = match.group(0)
        next_heading = re.search(r"^##\s+", text[match.end() :], re.MULTILINE)
        section_end = (
            match.end() + next_heading.start()
            if next_heading
            else len(text)
        )
        block = render_reference_block(action, kind, heading)
        suffix = text[section_end:]
        return text[: match.start()] + block + "\n\n" + suffix.lstrip("\n")

    heading = f"## {kind.title()}"
    block = render_reference_block(action, kind, heading)
    if kind == "outputs" and INPUT_END in text:
        insert_at = text.find(INPUT_END) + len(INPUT_END)
        return text[:insert_at] + "\n\n" + block + text[insert_at:]
    return text.rstrip() + "\n\n" + block + "\n"


def update_action_doc(text: str, action: Action) -> str:
    text = replace_reference_section(text, action, "inputs")
    text = replace_reference_section(text, action, "outputs")
    return text.rstrip() + "\n"


def catalogue_table(actions: list[Action], *, quarto: bool) -> str:
    lines = ["| Action | Description |", "| --- | --- |"]
    for action in actions:
        target = f"{action.slug}.qmd" if quarto else f"./{action.slug}/README.md"
        lines.append(
            f"| [{escape_cell(action.name)}]({target}) | {escape_cell(action.description)} |"
        )
    return "\n".join(lines)


def render_catalogue(actions: list[Action], *, quarto: bool) -> str:
    return (
        f"{CATALOGUE_START}\n"
        "<!-- Generated from */action.yml by scripts/generate-action-docs.py. Do not edit this block manually. -->\n"
        f"{catalogue_table(actions, quarto=quarto)}\n"
        f"{CATALOGUE_END}"
    )


def concise_root_readme(actions: list[Action]) -> str:
    catalogue = render_catalogue(actions, quarto=False)
    return f"""# Custom GitHub Actions

Reusable composite GitHub Actions for common CI/CD, release, repository and development-environment tasks.

## Available actions

{catalogue}

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
"""


def update_index(text: str, actions: list[Action]) -> str:
    block = render_catalogue(actions, quarto=True)
    start = text.find(CATALOGUE_START)
    end = text.find(CATALOGUE_END)
    if start != -1 and end != -1 and end > start:
        end += len(CATALOGUE_END)
        return (text[:start] + block + text[end:]).rstrip() + "\n"

    heading = re.search(r"^##\s+Available Actions\s*$", text, re.IGNORECASE | re.MULTILINE)
    if heading:
        next_heading = re.search(r"^##\s+", text[heading.end() :], re.MULTILINE)
        section_end = heading.end() + next_heading.start() if next_heading else len(text)
        replacement = f"{heading.group(0)}\n\n{block}\n\n"
        return (text[: heading.start()] + replacement + text[section_end:].lstrip("\n")).rstrip() + "\n"

    return text.rstrip() + f"\n\n## Available Actions\n\n{block}\n"


def yaml_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def qmd_from_readme(action: Action, readme: str) -> str:
    body = re.sub(r"^#\s+[^\n]+\n+", "", readme, count=1)
    return (
        f"---\ntitle: {yaml_quote(action.name)}\n---\n\n"
        f"{GENERATED_QMD_MARKER}\n"
        f"<!-- This page is generated from {action.slug}/README.md. -->\n\n"
        f"{body.lstrip()}"
    ).rstrip() + "\n"


def expected_files(root: Path) -> dict[Path, str]:
    action_paths = sorted(root.glob("*/action.yml"), key=lambda p: p.parent.name)
    actions = [parse_action(path) for path in action_paths]
    if not actions:
        raise RuntimeError(f"No */action.yml files found under {root}")

    changes: dict[Path, str] = {}
    for action in actions:
        readme_path = root / action.slug / "README.md"
        if not readme_path.exists():
            raise RuntimeError(f"Missing action README: {readme_path.relative_to(root)}")
        readme = update_action_doc(readme_path.read_text(encoding="utf-8"), action)
        changes[readme_path] = readme

        qmd_path = root / f"{action.slug}.qmd"
        if qmd_path.exists():
            current_qmd = qmd_path.read_text(encoding="utf-8")
            if GENERATED_QMD_MARKER in current_qmd:
                qmd = qmd_from_readme(action, readme)
            else:
                qmd = update_action_doc(current_qmd, action)
        else:
            qmd = qmd_from_readme(action, readme)
        changes[qmd_path] = qmd

    root_readme = root / "README.md"
    if root_readme.exists():
        current = root_readme.read_text(encoding="utf-8")
        if CATALOGUE_START in current and CATALOGUE_END in current:
            block = render_catalogue(actions, quarto=False)
            start = current.find(CATALOGUE_START)
            end = current.find(CATALOGUE_END) + len(CATALOGUE_END)
            changes[root_readme] = (current[:start] + block + current[end:]).rstrip() + "\n"
        else:
            changes[root_readme] = concise_root_readme(actions)

    index = root / "index.qmd"
    if index.exists():
        changes[index] = update_index(index.read_text(encoding="utf-8"), actions)

    return changes


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="update generated documentation")
    mode.add_argument("--check", action="store_true", help="fail if generated documentation is stale")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (defaults to the parent of scripts/)",
    )
    args = parser.parse_args()
    root = args.root.resolve()

    try:
        expected = expected_files(root)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    stale: list[Path] = []
    for path, content in expected.items():
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current == content:
            continue
        stale.append(path)
        if args.write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    if args.write:
        for path in stale:
            print(f"updated {path.relative_to(root)}")
        return 0

    if stale:
        print("Generated action documentation is stale:", file=sys.stderr)
        for path in stale:
            print(f"  {path.relative_to(root)}", file=sys.stderr)
        print("Run: python3 scripts/generate-action-docs.py --write", file=sys.stderr)
        return 1

    print("Generated action documentation is up to date.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

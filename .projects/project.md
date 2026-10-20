# actions Project configuration

| Key | Value |
| --- | --- |
| Contract version | 1 |
| Sub-project storage | field |
| Sub-project field | Sub-project |
| Sub-project field type | SINGLE_SELECT |
| Mode | single |
| Issue repository | MiguelRodo/actions |
| Project owner | MiguelRodo |
| Project number | 41 |
| Project title | actions |
| Routing | membership |
| Privacy | public repository; public issue content only |

## Field locations

| Common dimension | Provider location | Provider field |
| --- | --- | --- |
| Class | project field | Class |
| Priority | project field | Priority |
| Status | project field | Status |
| Parent | native issue relationship | Parent issue |
| Sub-project | project field | Sub-project |

## Governance

- This repository contributes to MiguelRodo Project #41 (`actions`).
- Native Project membership is authoritative; a checked Project selector or authority comment supplies explicit context.
- Issues intended for Project #41 require explicit native membership rather than depending on auto-add timing.
- `pj:implement-chat` is a local implementation handoff label, not a Project-routing label. Queue issues are not Project items by default.
- Labels must not duplicate Class, Priority or Status.
- Assignment is explicit only.
- The repository is public. Keep private material out of issues, pull requests, commits, logs and public reports.
- Exact requested administration and organising existing issues to this declared shape require no external source.

## Storage authority

- The field includes a schema-only `Not assigned` option. Leave unclassified item values blank; clearing does not select that option.
- `Sub-project` is the sole writable grouping representation. Legacy grouping labels are read-only migration artifacts until verified cleanup.
- Resolve field and option IDs freshly; require the exact configured name, SINGLE_SELECT type and vocabulary mapping. Stop if the expected field is missing or inaccessible.
- Multiple memberships require explicit Project context unless exactly one relevant managed membership resolves it. An explicit add-membership request may name its target before placement.

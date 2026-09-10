---
name: github-projects
description: Administer GitHub issues and Project 41 for this repository using the canonical MiguelRodo/github-projects-skill contract and operating rules.
---

# GitHub Project administration

This repository uses the canonical `github-projects` skill maintained in `MiguelRodo/github-projects-skill`.

Before any issue or Project administration:

1. Read `.projects/project.md` and treat it as the repository-specific contract.
2. Use the current canonical skill from `MiguelRodo/github-projects-skill/skills/github-projects/SKILL.md` for operating behaviour, field mutation safety, routing, prioritisation, Type/Class semantics, and the local Chat-to-`pj` queue.
3. Treat live GitHub as authoritative for Project membership, fields and option values. Do not guess provider IDs or options from this repository file.
4. Preserve unrelated issue labels, assignees, milestones, hierarchy, comments and Project values.
5. Use `pj:implement-chat` only for the local implementation queue. It is not the Project routing label.

For this repository, Project #41 (`actions`) is routed by `project:actions`; the precise field mappings and governance are in `.projects/project.md`.

If the canonical skill cannot be read, stop rather than improvising Project-administration behaviour.

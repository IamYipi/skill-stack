---
name: project-structure-index
description: Create and maintain a repository-local `structure_project.md` file that captures the project's structure, architecture, runtime flow, important files, commands, and conventions. Use when Codex needs a token-efficient project map for medium or large codebases, when onboarding into an unfamiliar repository, or when asked to create, refresh, extend, or rely on `structure_project.md` before normal coding prompts.
---

# Project Structure Index

## Overview

Build a durable project map in `structure_project.md` so future prompts can reuse a compact, repo-specific summary instead of rediscovering the entire codebase. Create the file on first use, then update it incrementally on later runs.

## Workflow

1. Detect the repository root and check whether `structure_project.md` already exists there.
2. If the file does not exist, perform a full project analysis before creating it.
3. If the file exists, read it first, then perform a lighter repo scan to discover additions, removals, and structural changes.
4. Update `structure_project.md` so it remains accurate, deduplicated, and easy to reuse in later prompts.

## Full Analysis Mode

When `structure_project.md` is missing:

- Inventory the repository with fast file discovery first.
- Read the main documentation and manifest files before drilling into implementation.
- Identify the main runtime entry points, feature modules, services, tests, tooling, configuration, and deployment-related files.
- Infer how the system works end to end, but clearly label any inference that is not directly verified from code or docs.
- Create `structure_project.md` at the repository root using the layout in [references/structure_project_template.md](references/structure_project_template.md).

## Incremental Update Mode

When `structure_project.md` already exists:

- Read the existing file before scanning anything else.
- Treat the existing file as the baseline project map.
- Run a high-level scan to detect new directories, new modules, renamed paths, removed components, new scripts, new integrations, and changed architectural boundaries.
- Update only the affected sections when possible instead of rewriting the entire file.
- Remove stale references when the underlying paths no longer exist.

## What To Capture

- Project purpose and high-level architecture
- Repository layout and the role of each major directory
- Main entry points, startup flow, and execution model
- Important modules, services, libraries, or apps
- Key configuration, environment, and build files
- Testing structure and how verification is done
- External integrations, data flow, and operational concerns
- Important conventions, constraints, and open questions worth preserving for later prompts

## Output Rules

- Write the output in English.
- Keep the file dense with useful facts, not long prose.
- Prefer representative paths over exhaustive file dumps.
- Use headings and short bullet lists so the file works as a reusable lookup document.
- Separate verified facts from inferred conclusions when needed.
- Keep the file current after each run so later prompts can reference it directly.

## Reference

Read [references/structure_project_template.md](references/structure_project_template.md) before creating or refreshing `structure_project.md`.

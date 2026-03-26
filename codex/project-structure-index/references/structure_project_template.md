# structure_project.md Template

Use this template as the default shape of `structure_project.md`. Adapt the sections to the repository, but keep the document easy to scan and cheap to reuse in later prompts.

## Recommended Structure

```md
# Project Structure

## 1. Purpose
- What the project does
- Primary users or systems
- Main problem it solves

## 2. High-Level Architecture
- Main applications, services, packages, or layers
- How they interact
- Key runtime flow

## 3. Repository Map
- `path/`: role of the directory
- `path/file.ext`: important reason this file matters

## 4. Entry Points And Execution Flow
- Main startup files
- Request, job, or event flow
- Background workers, schedulers, CLIs, or scripts

## 5. Core Modules
- Important features or domains
- Main classes, components, handlers, or services
- Internal dependencies worth remembering

## 6. Configuration And Environment
- Environment files and config sources
- Build, test, lint, or deployment configuration
- Secrets handling expectations if visible from the repo

## 7. Data And Integrations
- Databases, queues, storage, or external APIs
- Data flow between modules
- Third-party services and where they are wired in

## 8. Testing And Quality
- Test layout and frameworks
- How the project is validated
- Gaps or missing coverage worth noting

## 9. Operational Notes
- Deployment shape
- Monitoring, logging, security, or infrastructure notes
- Constraints that affect development work

## 10. Open Questions
- Unknowns
- Inferences that need confirmation
- Areas that should be revisited after deeper analysis
```

## Creation Rules

- Prefer concise facts over narrative explanations.
- Mention representative files and directories rather than dumping large trees.
- Explain why a path matters, not only that it exists.
- Mark uncertain conclusions with `Inference:`.

## Update Rules

When refreshing an existing `structure_project.md`:

1. Read the current document first.
2. Scan the repository for structural changes.
3. Update changed sections in place when possible.
4. Add new modules, directories, commands, and integrations.
5. Remove stale entries for paths that no longer exist.
6. Keep the wording compact so the file remains a token saver.

---
name: jira
description: >
  Query Jira issues from the CLI. Use when the user wants to search, list, or filter Jira issues,
  inspect sprints, check open tasks for a project, or run free-text searches against Jira. Trigger
  on mentions of Jira, issues, tickets, tasks, sprint, backlog, or project keys such as SIEM.
---

# Jira

## Overview

Use `scripts/jira_query.py` to query Jira REST API v2 from the local terminal.
Credentials resolve in this order:

1. Environment variables
2. `~/.codex/skills/jira/config.json`
3. Interactive prompt on first use

## Workflow

1. Prefer existing credentials:
   - `JIRA_TOKEN`
   - `JIRA_URL`
   - `JIRA_AUTH_MODE` (`bearer` by default, `basic` supported)
   - `JIRA_USER` (required for `basic`)
2. If credentials are missing and you are operating through Codex tooling, ask the user for the
   Jira URL and token instead of relying on an interactive prompt.
3. Build the command based on the user request.
4. Execute the script.
5. Interpret output:
   - standard human-readable format for small result sets
   - `META|...`, `FIELDS|...`, `ISSUE|...` lines for `--all`
6. If the script returns HTTP `401`, suggest `--reset-token` and re-authenticate.

## Commands

```bash
python scripts/jira_query.py [options]
```

Main arguments:

- `-p`, `--project`: project key, for example `SIEM`
- `-s`, `--search`: free-text search using `text ~`
- `--sprint`: sprint name or ID
- `-o`, `--open-only`: filter `statusCategory != Done`
- `-m`, `--max-results`: result limit for non-paginated mode
- `--all`: fetch every page and emit compact output
- `--include-description`: include the description field
- `--token`: one-shot Jira token override for the current execution
- `--url`: one-shot Jira URL override for the current execution
- `--auth-mode`: one-shot auth mode override, `bearer` or `basic`
- `--user`: one-shot Jira user override for `basic` auth
- `--reset-token`: remove the saved token from config
- `--reset-url`: remove the saved URL from config

Examples:

```bash
# Open issues for project SIEM
python scripts/jira_query.py -p SIEM -o

# Search in the current sprint
python scripts/jira_query.py -p SIEM --sprint "Stage 3" -o

# Free-text search with description
python scripts/jira_query.py -s "Prefect playbook" --include-description

# Full project listing in compact format
python scripts/jira_query.py -p SIEM --all
```

## Output

- Normal mode prints a short readable list of issues.
- `--all` prints compact lines suitable for machine parsing:

```text
META|total=42|showing=42|format=llm-compact
FIELDS|key|summary|description
ISSUE|SIEM-130|Fix playbook approval state|...
```

## Notes

- Saved credentials live in `~/.codex/skills/jira/config.json`.
- The script creates the config file with owner-only permissions when the platform supports it.
- The script does not save one-shot CLI overrides or environment-variable values unless the user is
  prompted interactively.

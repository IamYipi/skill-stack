---
name: jira
description: >
  Skill for querying Jira issues via CLI. Use it when the user wants to search, list, or filter Jira issues, check sprints, view open tasks for a project, or do free-text searches. On first use, prompts the user for their Jira token and URL, then persists them in ~/.claude/skills/jira/config.json for future use.
  Trigger on any mention of "Jira", "tasks", "sprint", "issues", "{Project_Name}"

---

# Jira Query Skill

CLI wrapper for the Jira REST API v2. Handles authentication automatically:
env var → config file → interactive prompt (first time only).

## Token & URL configuration

| Source | Details |
|---|---|
| `$JIRA_TOKEN` / `$JIRA_URL` | Highest priority |
| `~/.claude/skills/jira/config.json` | Auto-persisted after first login |
| Interactive prompt | Only if not found in the above sources |

To reset saved credentials:
```bash
python scripts/jira_query.py --reset-token
python scripts/jira_query.py --reset-url
```

The config file is created with `600` permissions (owner read-only).

## Optional environment variables

| Variable | Default | Description |
|---|---|---|
| `JIRA_URL` | _(prompted on first use)_ | Base URL of the Jira instance |
| `JIRA_AUTH_MODE` | `bearer` | `bearer` or `basic` |
| `JIRA_USER` | — | Required if `AUTH_MODE=basic` |

## Script usage

```bash
python scripts/jira_query.py [options]
```

### Main arguments

| Flag | Description |
|---|---|
| `-p / --project` | Project key (e.g. `{Project_Name}`) |
| `-s / --search` | Free-text search (JQL `text ~`) |
| `--sprint` | Sprint name or ID |
| `-o / --open-only` | Filter `statusCategory != Done` |
| `-m / --max-results` | Result limit (default: 10) |
| `--all` | Full pagination (compact output format) |
| `--include-description` | Include the description field |
| `--reset-token` | Remove saved token |
| `--reset-url` | Remove saved URL |

### Examples

```bash
# Open issues for project {Project_Name}
python scripts/jira_query.py -p {Project_Name} -o

# Search in the current sprint
python scripts/jira_query.py -p {Project_Name} --sprint "Stage 3" -o

# Free-text search with description
python scripts/jira_query.py -s "gRPC agent" --include-description

# All issues in a project (paginated)
python scripts/jira_query.py -p {Project_Name} --all
```

## Claude workflow

1. **Verify credentials**: run the script; if no token/URL is saved, the script will prompt
   the user interactively and persist them.
2. **Build the command** with the appropriate flags based on what the user asks.
3. **Execute** via `bash_tool`.
4. **Interpret output**: normal format for few issues, `ISSUE|key|summary`
   format for `--all` output.

> If the script returns HTTP 401, suggest `--reset-token` and re-authenticate.

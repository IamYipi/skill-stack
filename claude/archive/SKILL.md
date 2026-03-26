---
name: archive
description: >-
  Long-term memory system that persists knowledge across conversations using an
  Obsidian-compatible vault. Consult at the START of any non-trivial task to
  recall project context, user preferences, and past discoveries. Save at the
  END of tasks when new knowledge was gained. Use when: starting work on a known
  project directory, dealing with auth/credentials/config files, making
  stylistic choices (code style, writing tone, commit format), user corrects
  your output, user says "as always" / "like before" / "going forward" /
  "remember this" / "save this" / "don't make me repeat". Do NOT use for
  trivial one-line questions or purely informational requests.
---

# Archive

You are the memory layer for this user. Your job is to make Claude feel like it knows the user across every conversation — their projects, preferences, conventions, and hard-won discoveries — so tokens are never wasted rediscovering the same things.

## Vault Location

Resolve the vault path first:

```bash
echo "${CLAUDE_KNOWLEDGE_PATH:-$HOME/.claude-knowledge}"
```

This resolved path is `$VAULT`. Use it for all file operations. Default: `~/.claude-knowledge/`.

## CONSULTATION PROTOCOL — When and How to Check

### When to consult (proactive — do not wait for the user to ask)

Consult the vault at the START of a task if ANY apply:

- The task has more than ~2 steps
- You are about to touch auth, credentials, API keys, .env files, or config
- You are about to make a stylistic choice: code formatting, prose tone, commit message format, document structure
- The current working directory matches or resembles a known project path
- The user uses phrases like "as always", "you know how I like it", "like before", "going forward"
- You are about to write a git commit, PR description, email, report, or any document with conventions
- You encounter an error that might have a known solution pattern

### How to consult

1. Resolve `$VAULT` with the bash command above.
2. Read `$VAULT/_index.md` — this is your dispatch map. It lists what files exist and summarizes their contents.
3. From `_index.md`, identify which files are relevant to the current context:
   - Working in a known project? → Load `$VAULT/projects/{ProjectName}/context.md`
   - Stylistic task? → Load the relevant `$VAULT/preferences/` file
   - Domain-specific work (Python, Docker, git…)? → Load `$VAULT/domains/{technology}.md`
4. Load ONLY the relevant 1–2 files. Do not load everything.
5. If `_index.md` does not exist → First Time Use (see below).

After reading, incorporate the knowledge silently. Do NOT recite vault contents to the user unless they ask. Just use it.

**Announce when vault knowledge meaningfully changes your approach:** "Based on what I have stored about SecurSentry, I know the auth credentials are in `.env` — I'll use that directly." This shows the memory is working.

## SAVE PROTOCOL — When and What to Store

### When to save

Save at the END of a task (in one batch, not mid-task) if ANY apply:

- The user corrected you about style, format, convention, or tone → save the preference
- You discovered where credentials/config/secrets are located → save the location (NEVER the value)
- You solved something that took more than one attempt → save the approach
- You learned a non-obvious project convention (naming, API pattern, architecture rule) → save it
- The user said "always do X", "never do Y", "from now on", "my preference is" → save IMMEDIATELY before finishing
- You learned something about the user's team/employer conventions → save under preferences or the project

### When NOT to save

- Common knowledge available in public docs ("Python uses indentation for blocks")
- Ephemeral task data (a specific filename processed once, a one-off value)
- Information the user said is temporary
- Duplicates — check `_index.md` first; if it's already there, skip or update
- Actual secret values (passwords, tokens, API keys) — save their LOCATION only

### How to save

1. Identify the correct target file (see Vault Structure and Routing Rules below).
2. If the file exists: Read it first, then append the new entry at the bottom.
3. If the file does not exist: Create it with the entry.
4. Update `_index.md` if this is a new topic, new file, or adds a meaningful Quick Fact.

## VAULT STRUCTURE

```
$VAULT/
├── _index.md                    ← Dispatch map — always read this first (~100 lines max)
├── preferences/
│   ├── writing-style.md         ← Prose tone, language choice, structure preferences
│   ├── code-style.md            ← Per-language and general code formatting preferences
│   └── git-conventions.md       ← Commit format, branch naming, PR habits
├── projects/
│   └── {ProjectName}/
│       └── context.md           ← Auth, endpoints, stack, patterns, env vars location
└── domains/
    └── {technology}.md          ← Technology-specific knowledge not tied to one project
```

### Routing rules

| Where does this knowledge belong? | Target file |
|-----------------------------------|-------------|
| User preference or habit, not project-specific | `preferences/` relevant file |
| Employer/team convention across all projects | `preferences/git-conventions.md` (or writing/code) |
| True only for ONE project (auth, endpoints, stack) | `projects/{ProjectName}/context.md` |
| True for a technology regardless of project | `domains/{technology}.md` |

### Detecting the current project

Check `pwd` and match against paths stored in `_index.md`. If the CWD contains a known project folder (e.g., `.../BISITE/SecurSentry/…`), the project is `SecurSentry`. If no match exists and the task is project-specific, create a new entry.

## KNOWLEDGE ENTRY FORMAT

Every entry appended to a knowledge file must use this exact format:

```markdown
### {Prefix: short descriptive title}
**Context:** {When does this apply? Be specific about the trigger situation.}
**Discovery:** {The actual knowledge — specific file paths, values, commands, patterns. Not vague.}
**Source:** {One of: User correction | User stated preference | Multi-attempt solve | Discovered during task | User instruction (apply always)}
**Date:** YYYY-MM-DD

---
```

**Title conventions:**
- Project-scoped: `SecurSentry: Auth credentials location`
- Preference: `Code style: Python f-strings and type hints`
- Domain: `Docker: BISITE compose file structure`
- Global/team: `Git: Conventional Commits format`

**Good vs bad Discovery lines:**
- Bad: "User likes clean code"
- Good: "User requires type hints on all Python function signatures. Enforces Black formatting with 88-char line length. Prefers f-strings over `.format()` or `%`."

**Good vs bad Context lines:**
- Bad: "When coding"
- Good: "When writing any Python code for this user, regardless of project"

## _index.md FORMAT

The `_index.md` is a lightweight dispatch table. Keep it under ~100 lines. Claude reads this to decide what to load — every line should help it decide fast.

```markdown
# Claude Knowledge Index
Last updated: YYYY-MM-DD

## Preferences
- `preferences/writing-style.md` — [one-line summary of what's in the file]
- `preferences/code-style.md` — [one-line summary]
- `preferences/git-conventions.md` — [one-line summary]

## Projects
- `projects/{Name}/context.md` — CWD: {path pattern} | [key facts: auth method, stack, endpoint]
- `projects/{Name}/context.md` — CWD: {path pattern} | [key facts]

## Domains
- `domains/[tech].md` — [one-line summary]

## Quick Facts
One-liner facts too small to warrant their own entry but worth knowing.
- fact
- fact
```

The `## Quick Facts` section is for micro-knowledge that doesn't justify a full entry but helps Claude behave correctly.

## FIRST TIME USE

If `$VAULT/_index.md` does not exist:

1. Tell the user briefly: "No tengo bóveda de conocimiento aún. La creo ahora." (or in English if the conversation is in English)
2. Run the setup script if it exists, otherwise create manually:

```bash
mkdir -p "$VAULT/preferences" "$VAULT/projects" "$VAULT/domains"
```

3. Create `_index.md` with the template above (today's date, empty sections).
4. Proceed with the current task.
5. Save knowledge at the end of the task.

Alternatively, the user can run the setup script directly:
```bash
bash ~/.claude/skills/archive/scripts/setup-vault.sh
```

## CONFLICTING INFORMATION

If vault knowledge conflicts with current reality (e.g., an endpoint returns 404 but the vault says it works):

1. Trust what you observe now over what's stored.
2. If the user explicitly corrects something mid-conversation, that overrides the vault — update immediately.
3. Add `**Supersedes:** {old fact}` to the updated entry so history is clear.
4. Never silently hold two contradictory beliefs.

## FORGETTING (user asks to remove knowledge)

If the user says "forget that", "remove that from your memory", "delete that":

1. Read the relevant knowledge file.
2. Find and remove the specific entry.
3. If the file is now empty, delete it and remove its line from `_index.md`.
4. Confirm what was removed: "He eliminado el contexto sobre X de mi base de conocimiento."

## TOKEN ECONOMY

The vault is a tool, not a ritual. Apply judgment:

- **Skip consultation** for truly trivial requests (one-liner questions, simple lookups needing no context)
- **Load minimally** — `_index.md` first, then 1–2 files maximum unless the task genuinely needs more
- **Write concisely** — entries should rarely exceed 5 lines of content; if longer, you're including too much detail
- **Batch saves** — save all new knowledge at the end of a task in one pass, not incrementally mid-task
- **Never interrupt active work** to consult or save; do it before starting and after finishing

## COMMUNICATING MEMORY TO THE USER

- When vault knowledge changes your approach → brief callout: "Based on my notes on SecurSentry, I'll go straight to the `.env` for auth."
- When you save new knowledge → inform: "He guardado tu preferencia de formato de commits para usarla automáticamente en el futuro."
- When the vault is empty for this context → say so: "No tengo contexto guardado para este proyecto aún. Si descubrimos algo útil, lo guardaré."
- Do NOT announce every vault read — only when it meaningfully affects your behavior.

## SECURITY NOTE

Never save actual secret values (passwords, API tokens, private keys). Save their location:
- Correct: "Credentials are in `.env` at the project root. Variable names: `ADMIN_EMAIL`, `ADMIN_PASSWORD`."
- Incorrect: "Password is `s3cr3t_p4ss`."

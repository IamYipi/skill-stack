#!/usr/bin/env bash
# setup-vault.sh — Initialize the Claude persistent knowledge vault
#
# Usage:
#   bash setup-vault.sh                          # Uses ~/.claude-knowledge/ (default)
#   bash setup-vault.sh ~/path/to/custom/vault   # Custom location
#   CLAUDE_KNOWLEDGE_PATH=~/vault bash setup-vault.sh  # Via env var
#
# After running, open Obsidian and choose "Open folder as vault" → select the vault path.

set -euo pipefail

VAULT="${1:-${CLAUDE_KNOWLEDGE_PATH:-$HOME/.claude-knowledge}}"
TODAY=$(date +%Y-%m-%d)

echo "Claude Knowledge Vault — Setup"
echo "================================"
echo "Vault path: $VAULT"
echo ""

# Create directory structure
mkdir -p "$VAULT/preferences"
mkdir -p "$VAULT/projects"
mkdir -p "$VAULT/domains"
echo "✓ Directory structure created"

# Create _index.md only if it doesn't already exist
if [ ! -f "$VAULT/_index.md" ]; then
cat > "$VAULT/_index.md" << INDEXEOF
# Claude Knowledge Index
Last updated: ${TODAY}

## Preferences
<!-- Format: \`preferences/<file>.md\` — one-line summary of contents -->

## Projects
<!-- Format: \`projects/<Name>/context.md\` — CWD: <path pattern> | key facts -->

## Domains
<!-- Format: \`domains/<technology>.md\` — one-line summary of contents -->

## Quick Facts
<!-- One-liner facts: timezone, language preference, employer, project root paths, etc. -->
INDEXEOF
  echo "✓ _index.md created"
else
  echo "⚠ _index.md already exists — skipping (no overwrite)"
fi

# Create placeholder preference files (empty, ready to receive entries)
for fname in writing-style code-style git-conventions; do
  fpath="$VAULT/preferences/$fname.md"
  if [ ! -f "$fpath" ]; then
    echo "# ${fname}" > "$fpath"
    echo "" >> "$fpath"
    echo "<!-- Entries added by Claude as preferences are discovered -->" >> "$fpath"
    echo "✓ preferences/$fname.md created"
  else
    echo "  preferences/$fname.md already exists — skipping"
  fi
done

echo ""
echo "Vault ready at: $VAULT"
echo ""
echo "Next steps:"
echo "  • Open Obsidian → Open folder as vault → select: $VAULT"
echo "  • To use a custom path: set CLAUDE_KNOWLEDGE_PATH=$VAULT in your environment"
echo "  • Claude will start populating the vault automatically during tasks"

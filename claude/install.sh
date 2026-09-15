#!/bin/bash

set -e

if command -v claude &>/dev/null; then
    claude --update
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install plugins
"$WORKDIR/install-plugins.sh"

# Copy settings.json (use profile-specific version if available)
source "$(dirname "$0")/../lib/profile.sh"
settings_source="$WORKDIR/settings.json.${DOTFILES_PROFILE}"
if [[ ! -f "$settings_source" ]]; then
    settings_source="$WORKDIR/settings.json"
fi
cp "$settings_source" ~/.claude/settings.json

# Copy keybindings.json
cp "$WORKDIR/keybindings.json" ~/.claude/keybindings.json

# Copy CLAUDE.md
cp "$WORKDIR/CLAUDE.md" ~/.claude/CLAUDE.md

# Copy statusline script
cp "$WORKDIR/statusline.sh" ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh

# Create target directories
mkdir -p ~/.claude/rules
mkdir -p ~/.claude/skills
mkdir -p ~/.claude/agents
mkdir -p ~/.claude/hooks
mkdir -p ~/.claude/scripts
mkdir -p ~/.claude/output-styles
mkdir -p ~/.claude/style
mkdir -p ~/.claude/vault-template

# Copy rules directory (overwrites existing files)
cp -r "$WORKDIR/rules/"* ~/.claude/rules/

# Copy skills directory (overwrites existing files)
cp -r "$WORKDIR/skills/"* ~/.claude/skills/

# Copy style directory (overwrites existing files)
# Composed into the output style, NOT auto-loaded like rules/
cp -r "$WORKDIR/style/"* ~/.claude/style/

# Copy vault template (overwrites existing files)
# Reference material only, never copied into a vault by the installer
cp -r "$WORKDIR/vault-template/"* ~/.claude/vault-template/

# Copy agents directory (overwrites existing files)
cp -r "$WORKDIR/agents/"* ~/.claude/agents/

# Copy hooks directory (overwrites existing files)
cp -r "$WORKDIR/hooks/"* ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# Copy scripts directory (overwrites existing files)
cp -r "$WORKDIR/scripts/"* ~/.claude/scripts/
chmod +x ~/.claude/scripts/*.sh

# Compose output style from tracked sources list
mapfile -t _sources < <(grep -v '^\s*#' "$WORKDIR/output-style-sources.txt" | grep -v '^\s*$')
"$HOME/.claude/scripts/compose-output-style.sh" "${_sources[@]}"
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

# Copy settings.json (profile → parent → default via resolve_asset)
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/profile.sh
. "$DOTFILES_ROOT/lib/profile.sh"
# shellcheck source=../lib/asset.sh
. "$DOTFILES_ROOT/lib/asset.sh"
cp "$(resolve_asset "$WORKDIR/settings.json")" ~/.claude/settings.json

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

# Install repo trust helper (headless `claude -p` needs trusted folders)
mkdir -p ~/.local/bin
install -m 755 "$WORKDIR/scripts/claude-trust-repos.py" ~/.local/bin/claude-trust-repos
~/.local/bin/claude-trust-repos

# Compose output style from tracked sources list
mapfile -t _sources < <(grep -v '^\s*#' "$WORKDIR/output-style-sources.txt" | grep -v '^\s*$')
"$HOME/.claude/scripts/compose-output-style.sh" "${_sources[@]}"
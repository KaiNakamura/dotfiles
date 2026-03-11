#!/bin/bash

set -e

if command -v claude &>/dev/null; then
    claude --update
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy settings.json
cp "$WORKDIR/settings.json" ~/.claude/settings.json

# Copy CLAUDE.md
cp "$WORKDIR/CLAUDE.md" ~/.claude/CLAUDE.md

# Create target directories
mkdir -p ~/.claude/rules
mkdir -p ~/.claude/skills
mkdir -p ~/.claude/agents
mkdir -p ~/.claude/hooks

# Copy rules directory (overwrites existing files)
cp -r "$WORKDIR/rules/"* ~/.claude/rules/

# Copy skills directory (overwrites existing files)
cp -r "$WORKDIR/skills/"* ~/.claude/skills/

# Copy agents directory (overwrites existing files)
cp -r "$WORKDIR/agents/"* ~/.claude/agents/

# Copy hooks directory (overwrites existing files)
cp -r "$WORKDIR/hooks/"* ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
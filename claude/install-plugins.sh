#!/bin/bash
set -euo pipefail

expose_plugin_skill() {
    local plugin_id="$1" skill_name="$2"
    local path
    path=$(jq -er ".plugins[\"$plugin_id\"][0].installPath" ~/.claude/plugins/installed_plugins.json)
    mkdir -p "$HOME/.claude/skills/$skill_name"
    ln -sfn "$path/skills/$skill_name/SKILL.md" "$HOME/.claude/skills/$skill_name/SKILL.md"
}

# No plugins are currently installed.

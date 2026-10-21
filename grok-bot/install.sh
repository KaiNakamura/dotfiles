#!/bin/bash

set -e

REPO_URL="https://downloads.cursor.com/aptrepo"
SYSTEM_DESKTOP="/usr/share/applications/grok-bot.desktop"
USER_DESKTOP="$HOME/.local/share/applications/grok-bot.desktop"

# Install the repo's latest .deb whenever ours is older; the app refuses to run once outdated
packages=$(curl -fsSL "$REPO_URL/dists/grok-bot/main/binary-amd64/Packages")
latest=$(awk '/^Version:/ {print $2; exit}' <<< "$packages")
installed=$(dpkg-query -W -f='${Version}' grok-bot 2>/dev/null || true)
if [ -z "$installed" ] || dpkg --compare-versions "$installed" lt "$latest"; then
    deb_path=$(awk '/^Filename:/ {print $2; exit}' <<< "$packages")
    tmp_deb="$(mktemp -d)/grok-bot.deb"
    curl -fsSL -o "$tmp_deb" "$REPO_URL/$deb_path"
    sudo apt install -y "$tmp_deb"
    rm -f "$tmp_deb"
fi

# Native Wayland breaks maximize; a user-level launcher survives package upgrades
mkdir -p "$(dirname "$USER_DESKTOP")"
sed 's|^Exec=grok-bot|Exec=grok-bot --ozone-platform=x11|' "$SYSTEM_DESKTOP" > "$USER_DESKTOP"
update-desktop-database "$(dirname "$USER_DESKTOP")" 2>/dev/null || true

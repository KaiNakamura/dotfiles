#!/bin/bash

set -e

REPO_URL="https://downloads.cursor.com/aptrepo"
SYSTEM_DESKTOP="/usr/share/applications/grok-bot.desktop"
USER_DESKTOP="$HOME/.local/share/applications/grok-bot.desktop"

# The package adds its own apt source on install, so only the first install needs the .deb
if ! dpkg -s grok-bot >/dev/null 2>&1; then
    deb_path=$(curl -fsSL "$REPO_URL/dists/grok-bot/main/binary-amd64/Packages" | awk '/^Filename:/ {print $2; exit}')
    tmp_deb="$(mktemp -d)/grok-bot.deb"
    curl -fsSL -o "$tmp_deb" "$REPO_URL/$deb_path"
    sudo apt install -y "$tmp_deb"
    rm -f "$tmp_deb"
fi

# Native Wayland breaks maximize; a user-level launcher survives package upgrades
mkdir -p "$(dirname "$USER_DESKTOP")"
sed 's|^Exec=grok-bot|Exec=grok-bot --ozone-platform=x11|' "$SYSTEM_DESKTOP" > "$USER_DESKTOP"
update-desktop-database "$(dirname "$USER_DESKTOP")" 2>/dev/null || true

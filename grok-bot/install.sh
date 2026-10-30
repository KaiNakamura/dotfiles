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
# grok-bot-launch starts it through grok-bot.service: Electron logs land in
# ~/.local/state/grok-bot/grok-bot.log and a crash is relaunched
WORKDIR="$(cd -- "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.local/bin"
install -m 755 "$WORKDIR"/bin/grok-bot-logged "$WORKDIR"/bin/grok-bot-launch "$HOME/.local/bin/"
sed "s|^Exec=grok-bot|Exec=$HOME/.local/bin/grok-bot-launch|; s| -- %U| %U|" "$SYSTEM_DESKTOP" > "$USER_DESKTOP"
update-desktop-database "$(dirname "$USER_DESKTOP")" 2>/dev/null || true

# Electron's X11 paste waits forever on a CLIPBOARD owner that never answers;
# clipguard re-owns such a clipboard until Grok Bot ships electron/electron#54914
# clipguard loads libXRes via ctypes and re-owns through xclip
dpkg -s xclip libxres1 >/dev/null 2>&1 || sudo apt install -y xclip libxres1
mkdir -p "$HOME/.local/share/clipwatch" "$HOME/.config/systemd/user"
cp "$WORKDIR"/clipwatch/* "$HOME/.local/share/clipwatch/"
chmod +x "$HOME"/.local/share/clipwatch/*.py "$HOME"/.local/share/clipwatch/*.sh
cp "$WORKDIR"/systemd/*.service "$HOME/.config/systemd/user/"
# grok-bot.service has no [Install]: the launcher starts it, so a running
# instance is never restarted by this install
# reenable drops links from an older [Install] section; a copy already running
# holds the old code until it is restarted
if ! { systemctl --user daemon-reload \
    && systemctl --user reenable clipguard.service clipwatch.service; } 2>/dev/null; then
    echo "  Warning: no user systemd; enable clipguard and clipwatch after login"
elif [ -z "${DISPLAY:-}" ] \
    || ! systemctl --user restart clipguard.service clipwatch.service; then
    echo "  Warning: no X display; clipguard starts at next graphical login"
fi

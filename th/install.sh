#!/bin/bash
# The `th` thoughts vault CLI, plus the desktop-side helpers that go with it.
#
# th lives in its own repo and is installed from there, since it is a Rust
# binary and no package manager carries it. What lives here besides is the part
# th deliberately leaves out: the KDE and KWin knowledge that turns a list of
# agents into a list of windows. th itself stays portable and works over ssh on
# a box with no display, which is why the two halves are installed separately.

set -e

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="$HOME/.local/bin"
TH_REPO="https://github.com/KaiNakamura/th"

if command -v cargo > /dev/null 2>&1; then
    echo "  Installing: th"
    cargo install --git "$TH_REPO"
else
    echo "Note: cargo is not on PATH, so th itself was skipped. Install Rust,"
    echo "then: cargo install --git $TH_REPO"
fi

# The helpers below drive KWin over D-Bus, so they are meaningless anywhere
# else. th is already in by this point and works without them.
if [[ "${XDG_CURRENT_DESKTOP:-}" != *"KDE"* ]]; then
    echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Skipping th desktop helpers (KDE not detected)"
    exit 0
fi

mkdir -p "$TARGET_BIN"
for script in "$WORKDIR"/bin/*; do
    name=$(basename "$script")
    echo "  Installing: $name"
    cp "$script" "$TARGET_BIN/$name"
    chmod +x "$TARGET_BIN/$name"
done

# kwin-window-list prints what this pair keeps current: a KWin script that
# stays loaded and publishes every window change, and the D-Bus service that
# writes what it publishes to a file.
echo "  Installing: window-list service"
SERVICE_DST="$TARGET_BIN/window-list-service.py"
mkdir -p "$HOME/.local/share/dbus-1/services" "$HOME/.config/systemd/user"
cp "$WORKDIR/scripts/window-list-service.py" "$SERVICE_DST"
chmod +x "$SERVICE_DST"
cat > "$HOME/.local/share/dbus-1/services/org.hjkl.WindowList.service" << EOF
[D-BUS Service]
Name=org.hjkl.WindowList
Exec=/usr/bin/python3 $SERVICE_DST
SystemdService=window-list.service
EOF
cp "$WORKDIR/systemd/window-list.service" "$HOME/.config/systemd/user/window-list.service"
systemctl --user daemon-reload
systemctl --user enable window-list.service
# A copy already running holds the old code until it is restarted.
systemctl --user restart window-list.service

echo "  Installing: window-list-publisher KWin script"
if command -v kpackagetool6 > /dev/null 2>&1; then
    KPKG=kpackagetool6
    KWRITECONFIG=kwriteconfig6
else
    KPKG=kpackagetool5
    KWRITECONFIG=kwriteconfig5
fi
"$KPKG" --type KWin/Script -r window-list-publisher > /dev/null 2>&1 || true
"$KPKG" --type KWin/Script -i "$WORKDIR/kwin-scripts/window-list-publisher"
# Toggled off then on, so a KWin already running drops the old copy and loads
# this one.
"$KWRITECONFIG" --file kwinrc --group Plugins --key window-list-publisherEnabled false
qdbus org.kde.KWin /KWin reconfigure
"$KWRITECONFIG" --file kwinrc --group Plugins --key window-list-publisherEnabled true
qdbus org.kde.KWin /KWin reconfigure

echo "Done."

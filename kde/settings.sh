#!/bin/bash

# NOTE: Use `kcmshell5 --list` to see available modules, some other useful commands:
# `kreadconfig5 --file <file_name> --group <group_name> --key <key_name>`
# `kwriteconfig5 --file <file_name> --group <group_name> --key <key_name> <value>`

# ===== Appearance =====

# Theme: Breeze Dark
kwriteconfig5 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop

# Resolution Scale
kwriteconfig5 --file kwinrc --group Xwayland --key Scale 1.75

# Apply wallpaper
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$WORKDIR/apply-wallpaper.sh" ]]; then
    chmod +x "$WORKDIR/apply-wallpaper.sh"
    "$WORKDIR/apply-wallpaper.sh"
else
    echo "Warning: apply-wallpaper.sh not found in $WORKDIR"
fi

# ===== Behavior =====

# On login, always start with an empty session
kwriteconfig5 --file ksmserverrc --group General --key loginMode emptySession

# Number of Virtual Desktops
kwriteconfig5 --file kwinrc --group Desktops --key Number 10

# Disable animations (set animation speed to instant)
kwriteconfig5 --file kwinrc --group Compositing --key AnimationSpeed 0

# Reduce blur strength (range 1-15, default 15 is too strong for terminal transparency)
kwriteconfig5 --file kwinrc --group Effect-blur --key BlurStrength 5
kwriteconfig5 --file kwinrc --group Effect-blur --key NoiseStrength 0

# Disable middle-click paste
# Note: Requires Wayland session and session restart to take effect
kwriteconfig5 --file kwinrc --group General --key MiddleClickPaste false

# Filter task switcher to show only windows from current desktop
kwriteconfig5 --file kwinrc --group TabBox --key ShowOnlyCurrentDesktop true

# ===== Default Applications =====

# Kitty
kwriteconfig5 --file kdeglobals --group General --key TerminalApplication ~/.local/kitty.app/bin/kitty
kwriteconfig5 --file kdeglobals --group General --key TerminalService kitty.desktop

# Firefox
kwriteconfig5 --file kdeglobals --group General --key BrowserApplication firefox_firefox.desktop
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key application/pdf firefox_firefox.desktop;
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key text/html firefox_firefox.desktop;
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key x-scheme-handler/http firefox_firefox.desktop;
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key x-scheme-handler/https firefox_firefox.desktop;

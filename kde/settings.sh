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

# ===== Window Focus Indicator (Klassy Window Decoration) =====

# Disable ShapeCorners if previously installed
kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_shapecornersEnabled false

# Set Klassy as the window decoration
kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.klassy
kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key theme Klassy

# Outline: Breeze blue custom color, 3px (active=87% opacity, inactive=30% opacity)
KLASSY_RC="$HOME/.config/klassyrc"
kwriteconfig5 --file "$KLASSY_RC" --group Windeco --key ThinWindowOutlineStyle WindowOutlineCustomColor
kwriteconfig5 --file "$KLASSY_RC" --group Windeco --key ThinWindowOutlineCustomColor "61,174,233"
kwriteconfig5 --file "$KLASSY_RC" --group Windeco --key ThinWindowOutlineThickness 3.0

# Show outline on maximized and tiled windows
kwriteconfig5 --file "$KLASSY_RC" --group Windeco --key DrawBorderOnMaximizedWindows true

# Install maximized-window-gap KWin script (prevents shadow/outline clipping on maximized windows)
GAP_SCRIPT_SRC="$WORKDIR/kwin-scripts/maximized-window-gap"
GAP_SCRIPT_DST="$HOME/.local/share/kwin/scripts/maximized-window-gap"
if [[ -d "$GAP_SCRIPT_SRC" ]]; then
    mkdir -p "$GAP_SCRIPT_DST"
    cp -r "$GAP_SCRIPT_SRC"/* "$GAP_SCRIPT_DST"/
    kwriteconfig5 --file kwinrc --group Plugins --key maximized-window-gapEnabled true
fi

# ===== Behavior =====

# On login, always start with an empty session
kwriteconfig5 --file ksmserverrc --group General --key loginMode emptySession

# Number of Virtual Desktops
kwriteconfig5 --file kwinrc --group Desktops --key Number 10

# Disable animations (set animation speed to instant)
kwriteconfig5 --file kwinrc --group Compositing --key AnimationSpeed 0

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

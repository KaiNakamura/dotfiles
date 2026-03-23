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

# Outline: accent colour, 3px
KLASSY_RC="$HOME/.config/klassyrc"
kwriteconfig5 --file "$KLASSY_RC" --group Windeco --key ThinWindowOutlineStyle WindowOutlineAccentColor
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

# Focus stays on the screen the cursor is on when switching desktops
kwriteconfig5 --file kwinrc --group Windows --key SeparateScreenFocus true
kwriteconfig5 --file kwinrc --group Windows --key ActiveMouseScreen false

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

# Default Browser
source "$(dirname "$0")/../lib/profile.sh"

if [[ "$DOTFILES_PROFILE" == "work" ]]; then
    BROWSER_DESKTOP="google-chrome.desktop"
else
    BROWSER_DESKTOP="firefox_firefox.desktop"
fi

kwriteconfig5 --file kdeglobals --group General --key BrowserApplication "$BROWSER_DESKTOP"
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key application/pdf "$BROWSER_DESKTOP"
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key text/html "$BROWSER_DESKTOP"
# NOTE: x-scheme-handler/http and x-scheme-handler/https are intentionally NOT set here.
# Those are owned by open-browser.desktop (registered via apply-open-browser.sh).

#!/bin/bash

# Check if running KDE Plasma
if [[ "$XDG_CURRENT_DESKTOP" != *"KDE"* ]]; then
    echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Skipping KDE configuration"
    exit 1
fi

echo "KDE detected. Proceeding with configuration..."

# Config settings
# - TURN OFF RESTORE SESSION!!!
# 	- Had a crash actually brick my shit and be unable to restart
# 	- Desktop Session $\to$ Session Restore $\to$ Start with an empty session
# - Pointer speed: -0.40
# - Theme: Breeze Dark
# - Wallpaper: Mountain
# - Login screen, also set to Mountain (open containing folder in wallpaper settings `/usr/share/wallpapers/Mountain/contents/images_dark/`)
# - Splash Screen:
# 	- Originally I had this on "none" but maybe this is causing issues with the graphics loading
# 	- Keeping it on default for now
# - Resolution scale: 175%
# - Taskbar
# 	- Konsole
# 	- VS Code
# 	- Chrome (or Firefox, depends on personal vs. work)
# 	- Slack

# NOTE: Use `kcmshell6 --list` to see available modules
# Also useful is `kreadconfig6`

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configure shortcuts
if [[ -f "$WORKDIR/shortcuts.sh" ]]; then
    echo "Configuring keyboard shortcuts..."
    chmod +x "$WORKDIR/shortcuts.sh"
    "$WORKDIR/shortcuts.sh"
else
    echo "shortcuts.sh not found in $WORKDIR"
fi

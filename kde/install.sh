#!/bin/bash

# Check if running KDE Plasma
if [[ "$XDG_CURRENT_DESKTOP" != *"KDE"* ]]; then
    echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Skipping KDE configuration"
    exit 1
fi

echo "KDE detected. Proceeding with configuration..."

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

# Configure settings
if [[ -f "$WORKDIR/settings.sh" ]]; then
    echo "Configuring settings..."
    chmod +x "$WORKDIR/settings.sh"
    "$WORKDIR/settings.sh"
else
    echo "settings.sh not found in $WORKDIR"
fi
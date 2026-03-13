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

# Install Klassy window decoration (for active window outline)
if [[ -f "$WORKDIR/install-klassy.sh" ]]; then
    echo "Installing Klassy..."
    chmod +x "$WORKDIR/install-klassy.sh"
    "$WORKDIR/install-klassy.sh"
else
    echo "install-klassy.sh not found in $WORKDIR"
fi

# Configure shortcuts
if [[ -f "$WORKDIR/apply-kksrc.sh" ]]; then
    echo "Configuring keyboard shortcuts..."
    chmod +x "$WORKDIR/apply-kksrc.sh"
    "$WORKDIR/apply-kksrc.sh"
else
    echo "apply-kksrc.sh not found in $WORKDIR"
fi

# Configure settings
if [[ -f "$WORKDIR/settings.sh" ]]; then
    echo "Configuring settings..."
    chmod +x "$WORKDIR/settings.sh"
    "$WORKDIR/settings.sh"
else
    echo "settings.sh not found in $WORKDIR"
fi

# Configure scripts
if [[ -f "$WORKDIR/apply-scripts.sh" ]]; then
    echo "Configuring scripts..."
    chmod +x "$WORKDIR/apply-scripts.sh"
    "$WORKDIR/apply-scripts.sh"
else
    echo "apply-scripts.sh not found in $WORKDIR"
fi
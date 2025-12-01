#!/bin/bash

# Check if running KDE Plasma
if [[ "$XDG_CURRENT_DESKTOP" != *"KDE"* ]]; then
    echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Skipping Wayland configuration (KDE Plasma required)"
    exit 1
fi

echo "Installing Wayland session..."

# Check if plasma-workspace-wayland is installed
if dpkg -l | grep -q "plasma-workspace-wayland"; then
    echo "plasma-workspace-wayland is already installed"
else
    echo "Installing plasma-workspace-wayland..."
    sudo apt update
    sudo apt install -y plasma-workspace-wayland
fi

# Configure SDDM to default to Wayland session
# SDDM config can be in /etc/sddm.conf or /etc/sddm.conf.d/
# We'll create a config file in /etc/sddm.conf.d/ to set Wayland as default
SDDM_CONF_DIR="/etc/sddm.conf.d"
SDDM_CONF_FILE="$SDDM_CONF_DIR/wayland-default.conf"

echo "Configuring SDDM to default to Wayland session..."

# Create config directory if it doesn't exist
sudo mkdir -p "$SDDM_CONF_DIR"

# Create or update SDDM config file to set Wayland as default
# The session name for Plasma Wayland is typically "plasma-wayland"
sudo tee "$SDDM_CONF_FILE" > /dev/null <<EOF
[XDisplay]
Session=plasma-wayland
EOF
#!/bin/bash

# Exit on error
set -e

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Version to install
YDOTOOL_VERSION="v1.0.4"
GITHUB_REPO="ReimuNotMoe/ydotool"
INSTALL_DIR="/usr/local/bin"

echo "=== Installing ydotool ${YDOTOOL_VERSION} from GitHub releases ==="
echo ""

# Check if we should use apt or GitHub releases
USE_APT=false
if [ "$1" = "--use-apt" ]; then
    USE_APT=true
    echo "Using apt package manager (may be outdated)..."
fi

if [ "$USE_APT" = false ]; then
    # Install from GitHub releases
    echo "Downloading ydotool ${YDOTOOL_VERSION} from GitHub..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Download binaries
    echo "Downloading ydotool..."
    curl -L -o "$TEMP_DIR/ydotool" \
        "https://github.com/${GITHUB_REPO}/releases/download/${YDOTOOL_VERSION}/ydotool-release-ubuntu-latest"
    
    echo "Downloading ydotoold..."
    curl -L -o "$TEMP_DIR/ydotoold" \
        "https://github.com/${GITHUB_REPO}/releases/download/${YDOTOOL_VERSION}/ydotoold-release-ubuntu-latest"
    
    # Make binaries executable
    chmod +x "$TEMP_DIR/ydotool" "$TEMP_DIR/ydotoold"
    
    # Install binaries
    echo "Installing binaries to ${INSTALL_DIR}..."
    sudo cp "$TEMP_DIR/ydotool" "$INSTALL_DIR/ydotool"
    sudo cp "$TEMP_DIR/ydotoold" "$INSTALL_DIR/ydotoold"
    
    echo "✅ ydotool ${YDOTOOL_VERSION} installed successfully"
else
    # Install from apt (legacy/fallback)
    echo "Installing ydotool from apt package manager..."
    sudo apt update
    sudo apt install -y ydotool ydotoold
    echo "⚠️  WARNING: apt package may be outdated. Use without --use-apt flag to install from GitHub."
fi

# Add user to input group
echo "Adding user to input group..."
sudo usermod -aG input "$USER"
echo "WARNING: Please log out and back in for group changes to take effect"

# Ensure uinput module loads at boot
echo "Configuring uinput module to load at boot..."
sudo cp "$WORKDIR/uinput.conf" /etc/modules-load.d/uinput.conf

# Copy service file
sudo cp "$WORKDIR/ydotoold.service" /etc/systemd/system/

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable ydotoold
sudo systemctl start ydotoold

echo "ydotoold daemon started"

# Configure YDOTOOL_SOCKET environment variable for v1.0.4+
# v1.0.4+ looks for socket in /run/user/UID/.ydotool_socket by default
# but we configure daemon to use /tmp/.ydotool_socket for compatibility
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
    if ! grep -q "YDOTOOL_SOCKET" "$SHELL_RC"; then
        echo ""
        echo "Configuring YDOTOOL_SOCKET environment variable..."
        echo "export YDOTOOL_SOCKET=/tmp/.ydotool_socket" >> "$SHELL_RC"
        echo "✅ Added YDOTOOL_SOCKET to $SHELL_RC"
        echo "   Run 'source $SHELL_RC' or restart your shell to apply"
    else
        echo "✅ YDOTOOL_SOCKET already configured in $SHELL_RC"
    fi
fi


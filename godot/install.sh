#!/bin/bash

set -e

GODOT_VERSION="4.6.1"
GODOT_FLAVOR="stable"

INSTALL_DIR="$HOME/.local/godot"
BINARY="$INSTALL_DIR/godot"

# Check if already installed
if [[ -f "$BINARY" ]]; then
    echo "Godot is already installed, skipping download..."
else
    echo "Downloading Godot ${GODOT_VERSION}-${GODOT_FLAVOR}..."

    URL="https://downloads.godotengine.org/?version=${GODOT_VERSION}&flavor=${GODOT_FLAVOR}&slug=linux.x86_64.zip&platform=linux.64"

    TMP_ZIP=$(mktemp --suffix=.zip)
    curl -L "$URL" -o "$TMP_ZIP"
    unzip -o "$TMP_ZIP" -d /tmp/godot_extract
    rm -f "$TMP_ZIP"

    mkdir -p "$INSTALL_DIR"
    mv "/tmp/godot_extract/Godot_v${GODOT_VERSION}-${GODOT_FLAVOR}_linux.x86_64" "$BINARY"
    chmod +x "$BINARY"
    rm -rf /tmp/godot_extract

    echo "Godot installed to $BINARY"
fi

# Symlink to PATH
mkdir -p ~/.local/bin
ln -sf "$BINARY" ~/.local/bin/godot

# Download icon
echo "Downloading Godot icon..."
ICON_URL="https://raw.githubusercontent.com/godotengine/godot/master/icon.svg"
curl -L "$ICON_URL" -o "$INSTALL_DIR/icon.svg"

# Create .desktop file
echo "Creating .desktop file..."
mkdir -p ~/.local/share/applications
cp ./godot.desktop ~/.local/share/applications/godot.desktop
sed -i "s|GODOT_INSTALL_DIR|${INSTALL_DIR}|g" ~/.local/share/applications/godot.desktop

# Update desktop database so KDE picks it up immediately
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

echo "Godot setup complete."

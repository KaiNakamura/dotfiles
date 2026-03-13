#!/bin/bash

# Check if running KDE Plasma
if [[ "$XDG_CURRENT_DESKTOP" != *"KDE"* ]]; then
    echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Skipping open-browser configuration (KDE not detected)"
    exit 1
fi

echo "Configuring open-browser handler..."

# Check if qdbus is installed
if ! command -v qdbus &> /dev/null; then
    echo "Error: qdbus is not installed. The open-browser handler requires it."
    exit 1
fi

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$WORKDIR/open-browser"
TARGET_BIN="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

# Create target directories
mkdir -p "$TARGET_BIN"
mkdir -p "$DESKTOP_DIR"

# Ensure KWin scripting debug output is enabled (needed for journal parsing)
LOGGING_FILE="$HOME/.config/QtProject/qtlogging.ini"
if [[ -f "$LOGGING_FILE" ]]; then
    if ! grep -q "kwin_scripting.debug=true" "$LOGGING_FILE" 2>/dev/null; then
        echo "  Enabling KWin scripting debug output..."
        if grep -q "^\[Rules\]" "$LOGGING_FILE"; then
            sed -i '/^\[Rules\]/a kwin_scripting.debug=true' "$LOGGING_FILE"
        else
            echo -e "\n[Rules]\nkwin_scripting.debug=true" >> "$LOGGING_FILE"
        fi
    fi
else
    mkdir -p "$(dirname "$LOGGING_FILE")"
    echo -e "[Rules]\nkwin_scripting.debug=true" > "$LOGGING_FILE"
fi

# Install the wrapper script
echo "  Installing open-browser.sh to $TARGET_BIN"
cp "$SOURCE_DIR/open-browser.sh" "$TARGET_BIN/open-browser.sh"
chmod +x "$TARGET_BIN/open-browser.sh"

# Install the .desktop file
echo "  Installing open-browser.desktop to $DESKTOP_DIR"
cp "$SOURCE_DIR/open-browser.desktop" "$DESKTOP_DIR/open-browser.desktop"

# Register as URL handler for both http and https schemes
echo "  Registering open-browser.desktop as default URL handler..."
xdg-mime default open-browser.desktop x-scheme-handler/http
xdg-mime default open-browser.desktop x-scheme-handler/https
xdg-settings set default-web-browser open-browser.desktop 2>/dev/null

# Verify
HTTP_HANDLER=$(xdg-mime query default x-scheme-handler/http 2>/dev/null)
HTTPS_HANDLER=$(xdg-mime query default x-scheme-handler/https 2>/dev/null)
if [[ "$HTTP_HANDLER" == "open-browser.desktop" && "$HTTPS_HANDLER" == "open-browser.desktop" ]]; then
    echo "  Verified: x-scheme-handler/http and https set to open-browser.desktop"
else
    echo "  Warning: verification failed (http=${HTTP_HANDLER:-none}, https=${HTTPS_HANDLER:-none})"
    echo "  You may need to manually set the default browser in System Settings."
fi

echo "Done! Open-browser handler configured."

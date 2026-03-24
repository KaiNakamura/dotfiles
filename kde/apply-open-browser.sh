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
CONFIG_DIR="$HOME/.config/open-browser"

# Create target directories
mkdir -p "$TARGET_BIN"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$CONFIG_DIR"

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

# Generate the .desktop file with absolute path
echo "  Generating open-browser.desktop with absolute path"
sed "s|OPEN_BROWSER_BIN_PATH|$TARGET_BIN/open-browser.sh|" \
    "$SOURCE_DIR/open-browser.desktop" > "$DESKTOP_DIR/open-browser.desktop"

# Create browser config file if it doesn't exist
if [[ ! -f "$CONFIG_DIR/browser" ]]; then
    echo "  Creating browser config at $CONFIG_DIR/browser"
    DOTFILES_PROFILE=$(cat "$HOME/.dotfiles-profile" 2>/dev/null || echo "")
    case "$DOTFILES_PROFILE" in
        work)
            echo "chrome" > "$CONFIG_DIR/browser"
            echo "  Set browser to chrome (from dotfiles-profile: work)"
            ;;
        *)
            if command -v google-chrome-stable &> /dev/null; then
                echo "chrome" > "$CONFIG_DIR/browser"
                echo "  Set browser to chrome (detected)"
            elif command -v firefox &> /dev/null; then
                echo "firefox" > "$CONFIG_DIR/browser"
                echo "  Set browser to firefox (detected)"
            elif command -v chromium-browser &> /dev/null || command -v chromium &> /dev/null; then
                echo "chromium" > "$CONFIG_DIR/browser"
                echo "  Set browser to chromium (detected)"
            else
                echo "chrome" > "$CONFIG_DIR/browser"
                echo "  Set browser to chrome (default)"
            fi
            ;;
    esac
else
    echo "  Browser config already exists at $CONFIG_DIR/browser ($(cat "$CONFIG_DIR/browser"))"
fi

# Register as URL handler for http, https, and HTML MIME types
echo "  Registering open-browser.desktop as default URL handler..."
xdg-mime default open-browser.desktop x-scheme-handler/http
xdg-mime default open-browser.desktop x-scheme-handler/https
xdg-mime default open-browser.desktop text/html
xdg-mime default open-browser.desktop application/xhtml+xml
xdg-settings set default-web-browser open-browser.desktop 2>/dev/null

# Verify
HTTP_HANDLER=$(xdg-mime query default x-scheme-handler/http 2>/dev/null)
HTTPS_HANDLER=$(xdg-mime query default x-scheme-handler/https 2>/dev/null)
HTML_HANDLER=$(xdg-mime query default text/html 2>/dev/null)
if [[ "$HTTP_HANDLER" == "open-browser.desktop" && "$HTTPS_HANDLER" == "open-browser.desktop" && "$HTML_HANDLER" == "open-browser.desktop" ]]; then
    echo "  Verified: all MIME types set to open-browser.desktop"
else
    echo "  Warning: verification failed"
    echo "    http=${HTTP_HANDLER:-none}"
    echo "    https=${HTTPS_HANDLER:-none}"
    echo "    text/html=${HTML_HANDLER:-none}"
    echo "  You may need to manually set the default browser in System Settings."
fi

echo "Done! Open-browser handler configured."

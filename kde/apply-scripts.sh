#!/bin/bash

# Check if running KDE Plasma
if [[ "$XDG_CURRENT_DESKTOP" != *"KDE"* ]]; then
    echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Skipping script installation (KDE not detected)"
    exit 1
fi

echo "Configuring scripts..."

# Check if xdotool is installed (required for cursor movement on X11)
if ! command -v xdotool &> /dev/null; then
    echo "xdotool is not installed. Installing it now..."
    echo "The window switch scripts require xdotool to move the cursor."
    
    # Try to install xdotool
    if sudo apt-get update && sudo apt-get install -y xdotool; then
        echo "xdotool installed successfully."
    else
        echo "Error: Failed to install xdotool."
        echo "Please install it manually with: sudo apt-get install xdotool"
        echo "The scripts will be installed but won't work until xdotool is available."
    fi
    echo ""
fi

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$WORKDIR/scripts"
TARGET_BIN="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

# Check if scripts directory exists
if [[ ! -d "$SCRIPT_DIR" ]]; then
    echo "Error: scripts directory not found at $SCRIPT_DIR"
    exit 1
fi

# Create target directories
mkdir -p "$TARGET_BIN"
mkdir -p "$DESKTOP_DIR"

# Install all scripts to ~/.local/bin
echo "Installing scripts..."
scripts_installed=0
for script_file in "$SCRIPT_DIR"/kwin-*.sh; do
    if [[ ! -f "$script_file" ]]; then
        continue
    fi
    
    script_name=$(basename "$script_file")
    target_file="$TARGET_BIN/$script_name"
    
    echo "  Installing: $script_name"
    cp "$script_file" "$target_file"
    chmod +x "$target_file"
    ((scripts_installed++))
done

if [[ $scripts_installed -eq 0 ]]; then
    echo "Error: No scripts found to install."
    exit 1
fi

echo "Installed $scripts_installed scripts to $TARGET_BIN"

# Define shortcuts to create
# Format: shortcut_id:key_combo:script_name:friendly_name
declare -a shortcuts=(
    # Window switching (center cursor)
    "kwin-switch-left:Meta+H:kwin-switch-left.sh:Switch Window Left with Cursor"
    "kwin-switch-down:Meta+J:kwin-switch-down.sh:Switch Window Down with Cursor"
    "kwin-switch-up:Meta+K:kwin-switch-up.sh:Switch Window Up with Cursor"
    "kwin-switch-right:Meta+L:kwin-switch-right.sh:Switch Window Right with Cursor"
    # Window move to screen (center cursor)
    "kwin-move-screen-left:Meta+Shift+H:kwin-move-screen-left.sh:Move Window to Screen Left with Cursor"
    "kwin-move-screen-down:Meta+Shift+J:kwin-move-screen-down.sh:Move Window to Screen Down with Cursor"
    "kwin-move-screen-up:Meta+Shift+K:kwin-move-screen-up.sh:Move Window to Screen Up with Cursor"
    "kwin-move-screen-right:Meta+Shift+L:kwin-move-screen-right.sh:Move Window to Screen Right with Cursor"
)

# Create desktop files
echo "Creating desktop files for shortcuts..."
for shortcut_def in "${shortcuts[@]}"; do
    IFS=':' read -r shortcut_id key_combo script_name friendly_name <<< "$shortcut_def"
    script_path="$TARGET_BIN/$script_name"
    desktop_file="$DESKTOP_DIR/${shortcut_id}.desktop"
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Type=Application
Name=$friendly_name
Exec=bash $script_path
NoDisplay=true
X-KDE-StartupNotify=false
EOF
    
    chmod +x "$desktop_file"
done

# Register shortcuts in kglobalshortcutsrc
CONFIG_FILE="$HOME/.config/kglobalshortcutsrc"

# Backup config
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Remove all existing kwin-switch and kwin-move-screen sections
sed -i '/^\[kwin-switch.*\.desktop\]/,/^\[/d' "$CONFIG_FILE" 2>/dev/null
sed -i '/^\[kwin-move-screen.*\.desktop\]/,/^\[/d' "$CONFIG_FILE" 2>/dev/null
# Also remove any standalone kwin-switch-* entries (non-desktop format)
sed -i '/^kwin-switch-[a-z]*=/d' "$CONFIG_FILE" 2>/dev/null
sed -i '/^kwin-move-screen-[a-z]*=/d' "$CONFIG_FILE" 2>/dev/null
# Remove stray _launch entries in [kwin] section that conflict with our shortcuts
sed -i '/^\[kwin\]/,/^\[/{ /^_launch=Meta+[HJKL]/d; /^_launch=Meta+Shift+[HJKL]/d; }' "$CONFIG_FILE" 2>/dev/null

# Register shortcuts using kwriteconfig5
echo "Registering shortcuts..."
for shortcut_def in "${shortcuts[@]}"; do
    # Parse shortcut definition (format: id:key_combo:script:friendly_name)
    shortcut_id=$(echo "$shortcut_def" | cut -d':' -f1)
    key_combo=$(echo "$shortcut_def" | cut -d':' -f2)
    friendly_name=$(echo "$shortcut_def" | cut -d':' -f4)
    section="${shortcut_id}.desktop"
    
    echo "  $key_combo -> $friendly_name"
    kwriteconfig5 --file kglobalshortcutsrc --group "$section" --key "_launch" "${key_combo},none,${friendly_name}" 2>/dev/null
done

# Reload shortcuts
# On Wayland, kglobalaccel is embedded in kwin_wayland, not a standalone systemd service
# On X11, kglobalaccel runs as a standalone systemd service
# Detect session type to use the appropriate reload method
echo "Reloading keyboard shortcuts..."

# Detect session type
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
if [[ "$SESSION_TYPE" == "wayland" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
    SESSION_TYPE="wayland"
else
    SESSION_TYPE="x11"
fi

if [[ "$SESSION_TYPE" == "wayland" ]]; then
    # Wayland: kglobalaccel is embedded in kwin_wayland
    # Systemd service restart will fail because D-Bus name is already registered
    # Use D-Bus reload method instead
    echo "Detected Wayland session - using D-Bus reload method..."
    
    if command -v qdbus &> /dev/null && qdbus org.kde.KWin /KWin &>/dev/null 2>&1; then
        echo "Attempting to reload shortcuts via D-Bus..."
        if qdbus org.kde.KWin /KWin reconfigure &>/dev/null 2>&1; then
            echo "Shortcuts reloaded via D-Bus."
        else
            echo "D-Bus reload attempted. Changes saved to ~/.config/kglobalshortcutsrc"
            echo "Note: You may need to log out and back in for all shortcuts to take full effect."
        fi
    else
        echo "Changes saved to ~/.config/kglobalshortcutsrc"
        echo "Note: You may need to log out and back in for all shortcuts to take full effect."
    fi
else
    # X11: kglobalaccel runs as standalone systemd service
    # Prefer systemd restart, fall back to D-Bus if needed
    echo "Detected X11 session - attempting systemd service restart..."
    
    if systemctl --user list-unit-files | grep -q "plasma-kglobalaccel.service"; then
        # Check if service is active before trying restart
        if systemctl --user is-active --quiet plasma-kglobalaccel.service; then
            if systemctl --user restart plasma-kglobalaccel.service; then
                sleep 1
                echo "Shortcuts reloaded successfully via systemd service restart."
            else
                echo "Warning: Failed to restart plasma-kglobalaccel.service, trying D-Bus reload..."
                # Fallback to D-Bus reload if systemd restart fails
                if command -v qdbus &> /dev/null && qdbus org.kde.KWin /KWin &>/dev/null 2>&1; then
                    if qdbus org.kde.KWin /KWin reconfigure &>/dev/null 2>&1; then
                        echo "Shortcuts reloaded via D-Bus fallback."
                    else
                        echo "Changes saved to ~/.config/kglobalshortcutsrc"
                        echo "Please log out and back in, or restart KDE for changes to take effect."
                    fi
                else
                    echo "Changes saved to ~/.config/kglobalshortcutsrc"
                    echo "Please log out and back in, or restart KDE for changes to take effect."
                fi
            fi
        else
            echo "Service not running, attempting to start..."
            if systemctl --user start plasma-kglobalaccel.service; then
                echo "Service started successfully."
            else
                echo "Warning: Could not start plasma-kglobalaccel.service"
                echo "Changes saved to ~/.config/kglobalshortcutsrc"
                echo "Please log out and back in, or restart KDE for changes to take effect."
            fi
        fi
    else
        echo "Warning: plasma-kglobalaccel.service not found, trying D-Bus reload..."
        # Fallback to D-Bus if systemd service doesn't exist
        if command -v qdbus &> /dev/null && qdbus org.kde.KWin /KWin &>/dev/null 2>&1; then
            if qdbus org.kde.KWin /KWin reconfigure &>/dev/null 2>&1; then
                echo "Shortcuts reloaded via D-Bus fallback."
            else
                echo "Changes saved to ~/.config/kglobalshortcutsrc"
                echo "Please log out and back in, or restart KDE for changes to take effect."
            fi
        else
            echo "Changes saved to ~/.config/kglobalshortcutsrc"
            echo "Please log out and back in, or restart KDE for changes to take effect."
        fi
    fi
fi

echo "Done! Scripts configured."


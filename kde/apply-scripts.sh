#!/bin/bash

# Check if running KDE Plasma
if [[ "$XDG_CURRENT_DESKTOP" != *"KDE"* ]]; then
    echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Skipping script installation (KDE not detected)"
    exit 1
fi

echo "Configuring scripts..."

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
# NOTE: Move-to-screen shortcuts (Meta+Shift+HJKL) are now handled by the
# hjkl-edge-guard KWin script. See kde/kwin-scripts/hjkl-edge-guard/
declare -a shortcuts=(
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

# Reload kglobalaccel service first (to register desktop files)
echo "Reloading kglobalaccel service..."
if systemctl --user restart plasma-kglobalaccel.service 2>/dev/null; then
    sleep 1  # Give service time to register desktop files
    echo "Service reloaded successfully."
else
    echo "Warning: Failed to restart plasma-kglobalaccel.service"
    echo "You may need to log out and back in for shortcuts to take effect."
fi

# Register shortcuts AFTER service restart (using kwriteconfig5)
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

# Reload service to pick up the key bindings
echo "Reloading kglobalaccel service to apply key bindings..."
if systemctl --user restart plasma-kglobalaccel.service 2>/dev/null; then
    sleep 1
    # Re-apply shortcuts after restart (they get cleared by service restart)
    for shortcut_def in "${shortcuts[@]}"; do
        shortcut_id=$(echo "$shortcut_def" | cut -d':' -f1)
        key_combo=$(echo "$shortcut_def" | cut -d':' -f2)
        friendly_name=$(echo "$shortcut_def" | cut -d':' -f4)
        section="${shortcut_id}.desktop"
        kwriteconfig5 --file kglobalshortcutsrc --group "$section" --key "_launch" "${key_combo},none,${friendly_name}" 2>/dev/null
    done
    echo "Shortcuts configured successfully."
else
    echo "Warning: Failed to restart plasma-kglobalaccel.service"
    echo "You may need to log out and back in for shortcuts to take effect."
fi

echo "Done! Scripts configured."


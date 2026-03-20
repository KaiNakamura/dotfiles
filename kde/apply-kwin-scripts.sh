#!/bin/bash
# apply-kwin-scripts.sh - Install and enable KWin JavaScript script packages

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$WORKDIR/kwin-scripts"

if [[ ! -d "$SCRIPTS_DIR" ]]; then
    echo "Error: kwin-scripts directory not found at $SCRIPTS_DIR"
    exit 1
fi

# Detect kpackagetool version
if command -v kpackagetool6 &>/dev/null; then
    KPACKAGETOOL="kpackagetool6"
    KWRITECONFIG="kwriteconfig6"
elif command -v kpackagetool5 &>/dev/null; then
    KPACKAGETOOL="kpackagetool5"
    KWRITECONFIG="kwriteconfig5"
else
    echo "Error: Neither kpackagetool5 nor kpackagetool6 found"
    exit 1
fi

echo "Using $KPACKAGETOOL for KWin script installation..."

# Install each KWin script package
for script_dir in "$SCRIPTS_DIR"/*/; do
    [[ ! -d "$script_dir" ]] && continue
    [[ ! -f "$script_dir/metadata.json" ]] && continue

    script_name="$(basename "$script_dir")"
    echo "Installing KWin script: $script_name"

    # Try install first, fall back to update if already installed
    if ! $KPACKAGETOOL --type=KWin/Script -i "$script_dir" 2>/dev/null; then
        $KPACKAGETOOL --type=KWin/Script -u "$script_dir"
    fi

    # Enable the script
    $KWRITECONFIG --file kwinrc --group Plugins --key "${script_name}Enabled" true
    echo "Enabled KWin script: $script_name"
done

# Reload KWin configuration
# On Wayland, kglobalaccel is embedded in kwin_wayland, not a standalone systemd service
# On X11, kglobalaccel runs as a standalone systemd service
echo "Reloading KWin configuration..."

SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
if [[ "$SESSION_TYPE" == "wayland" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
    SESSION_TYPE="wayland"
else
    SESSION_TYPE="x11"
fi

if [[ "$SESSION_TYPE" == "wayland" ]]; then
    echo "Detected Wayland session - using D-Bus reload method..."
    if command -v qdbus &>/dev/null && qdbus org.kde.KWin /KWin &>/dev/null 2>&1; then
        if qdbus org.kde.KWin /KWin reconfigure &>/dev/null 2>&1; then
            echo "KWin reloaded via D-Bus."
        else
            echo "D-Bus reload attempted. You may need to log out and back in."
        fi
    else
        echo "You may need to log out and back in for KWin scripts to take effect."
    fi
else
    echo "Detected X11 session - using D-Bus reload..."
    if command -v qdbus &>/dev/null && qdbus org.kde.KWin /KWin &>/dev/null 2>&1; then
        if qdbus org.kde.KWin /KWin reconfigure &>/dev/null 2>&1; then
            echo "KWin reloaded via D-Bus."
        else
            echo "You may need to log out and back in for KWin scripts to take effect."
        fi
    else
        echo "You may need to log out and back in for KWin scripts to take effect."
    fi
fi

echo "Done! KWin scripts applied."

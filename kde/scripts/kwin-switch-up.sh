#!/bin/bash
# kwin-switch-up.sh - Switch window up and center cursor

# Execute KWin action
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "Switch Window Up"

# Use helper to center cursor
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/kwin-center-cursor.sh"


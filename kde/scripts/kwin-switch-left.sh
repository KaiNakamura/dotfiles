#!/bin/bash
# kwin-switch-left.sh - Switch window left and center cursor

# Execute KWin action
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "Switch Window Left"

# Use helper to center cursor
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/kwin-center-cursor.sh"


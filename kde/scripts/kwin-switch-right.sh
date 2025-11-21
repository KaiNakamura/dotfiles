#!/bin/bash
# kwin-switch-right.sh - Switch window right and center cursor

# Execute KWin action
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "Switch Window Right"

# Use helper to center cursor
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/kwin-center-cursor.sh"


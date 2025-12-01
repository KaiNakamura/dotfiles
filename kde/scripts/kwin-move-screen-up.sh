#!/bin/bash
# kwin-move-screen-up.sh - Move window to screen up and center cursor

# Execute KWin action (move window to different screen)
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "Window One Screen Up"

# Move cursor to center using helper script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/kwin-center-cursor.sh"


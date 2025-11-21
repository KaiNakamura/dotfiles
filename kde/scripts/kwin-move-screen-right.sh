#!/bin/bash
# kwin-move-screen-right.sh - Move window to screen right and center cursor

# Execute KWin action (move window to different screen)
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "Window One Screen to the Right"

# Small delay to ensure window has moved
sleep 0.01

# Move cursor to center using helper script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/kwin-center-cursor.sh"


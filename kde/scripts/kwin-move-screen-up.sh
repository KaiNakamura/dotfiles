#!/bin/bash
# kwin-move-screen-up.sh - Move window to screen up and center cursor

# Source shared helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/kwin-screen-helpers.sh"

# Direction-specific configuration
DIRECTION="up"
KWIN_SHORTCUT="Window One Screen Up"

# Parse geometries
parse_all_screen_geometries

# Get current screen
CURRENT_SCREEN=$(get_current_screen)
[[ -z "$CURRENT_SCREEN" ]] && exit 0

# Find neighbor
NEIGHBOR_SCREEN=$(find_neighbor_screen "$CURRENT_SCREEN" "$DIRECTION")
[[ -z "$NEIGHBOR_SCREEN" ]] && exit 0

# Execute shortcut
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "$KWIN_SHORTCUT"

# Calculate center and move cursor
NEIGHBOR_GEOM=$(get_screen_geometry "$NEIGHBOR_SCREEN")
read -r x y width height <<< "$NEIGHBOR_GEOM"
CENTER_X=$((x + width / 2))
CENTER_Y=$((y + height / 2))

move_cursor_to_coordinates "$CENTER_X" "$CENTER_Y"


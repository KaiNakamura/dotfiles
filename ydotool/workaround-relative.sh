#!/bin/bash
# Workaround for ydotool absolute coordinate bug
# Uses relative movement from top-left corner (0,0) to reach target coordinates
# This is a workaround until the absolute coordinate bug is fixed

set -e

export YDOTOOL_SOCKET=/tmp/.ydotool_socket

if [ $# -lt 2 ]; then
    echo "Usage: $0 <target_x> <target_y>"
    echo "Example: $0 960 540"
    exit 1
fi

TARGET_X=$1
TARGET_Y=$2

echo "=== ydotool Absolute Movement Workaround ==="
echo "Target coordinates: ($TARGET_X, $TARGET_Y)"
echo ""
echo "Workaround: Moving to (0,0) first, then relative movement to target"
echo ""

# Step 1: Move to origin (0,0) using absolute (this works - goes to top-left)
echo "Step 1: Moving to origin (0,0)..."
ydotool mousemove --absolute -x 0 -y 0 2>&1
sleep 0.05  # Small delay to ensure movement completes

# Step 2: Move relatively from (0,0) to target
echo "Step 2: Moving relatively to ($TARGET_X, $TARGET_Y)..."
ydotool mousemove -x "$TARGET_X" -y "$TARGET_Y" 2>&1

echo ""
echo "✅ Movement complete"
echo ""
echo "NOTE: This is a workaround for the absolute coordinate bug."
echo "      If relative movement doesn't work accurately, this may not be reliable."


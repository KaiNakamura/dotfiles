#!/bin/bash
# Script to dynamically detect ydotool coordinate scaling factor
# This tests actual cursor movement to determine the scaling factor

set -e

export YDOTOOL_SOCKET=/tmp/.ydotool_socket

echo "=== ydotool Coordinate Scaling Factor Detection ==="
echo ""

# Check if required tools are available
if ! command -v ydotool &> /dev/null; then
    echo "ERROR: ydotool not installed"
    exit 1
fi

if ! command -v xdotool &> /dev/null; then
    echo "ERROR: xdotool not installed (needed to query cursor position)"
    exit 1
fi

if ! pgrep -x ydotoold > /dev/null; then
    echo "ERROR: ydotoold daemon not running"
    exit 1
fi

echo "This script will:"
echo "1. Move cursor to (0,0) using absolute coordinates"
echo "2. Move relatively by a known amount (100, 100)"
echo "3. Query actual cursor position"
echo "4. Calculate scaling factor based on actual vs expected movement"
echo ""
echo "Starting test in 3 seconds..."
sleep 3

# Step 1: Move to (0,0)
echo "Step 1: Moving to (0,0)..."
ydotool mousemove --absolute -x 0 -y 0 2>/dev/null
sleep 0.1

# Get position after absolute move (should be at 0,0 or close)
POS_AFTER_ABS=$(xdotool getmouselocation 2>/dev/null)
ABS_X=$(echo "$POS_AFTER_ABS" | grep -oP 'x:\K\d+' | head -1)
ABS_Y=$(echo "$POS_AFTER_ABS" | grep -oP 'y:\K\d+' | head -1)
echo "  Position after absolute (0,0): ($ABS_X, $ABS_Y)"

# Step 2: Move relatively by (100, 100)
echo "Step 2: Moving relatively by (100, 100)..."
ydotool mousemove -x 100 -y 100 2>/dev/null
sleep 0.5

# Get final position
POS_FINAL=$(xdotool getmouselocation 2>/dev/null)
FINAL_X=$(echo "$POS_FINAL" | grep -oP 'x:\K\d+' | head -1)
FINAL_Y=$(echo "$POS_FINAL" | grep -oP 'y:\K\d+' | head -1)
echo "  Final position: ($FINAL_X, $FINAL_Y)"

# Calculate actual movement
ACTUAL_X=$((FINAL_X - ABS_X))
ACTUAL_Y=$((FINAL_Y - ABS_Y))
echo "  Actual movement: ($ACTUAL_X, $ACTUAL_Y) pixels"
echo "  Expected movement: (100, 100) pixels"

# Calculate scaling factor
if [[ $ACTUAL_X -gt 0 ]]; then
    SCALE_X=$(echo "scale=3; $ACTUAL_X / 100" | bc 2>/dev/null || echo "unknown")
else
    SCALE_X="unknown"
fi

if [[ $ACTUAL_Y -gt 0 ]]; then
    SCALE_Y=$(echo "scale=3; $ACTUAL_Y / 100" | bc 2>/dev/null || echo "unknown")
else
    SCALE_Y="unknown"
fi

echo ""
echo "=== Results ==="
echo "X-axis scaling factor: $SCALE_X (actual/expected)"
echo "Y-axis scaling factor: $SCALE_Y (actual/expected)"
echo ""

# Determine if scaling is consistent
if [[ "$SCALE_X" != "unknown" ]] && [[ "$SCALE_Y" != "unknown" ]]; then
    # Check if scaling is approximately 0.5x
    SCALE_X_INT=$(echo "$SCALE_X * 1000" | bc 2>/dev/null | cut -d. -f1)
    SCALE_Y_INT=$(echo "$SCALE_Y * 1000" | bc 2>/dev/null | cut -d. -f1)
    
    if [[ $SCALE_X_INT -ge 450 ]] && [[ $SCALE_X_INT -le 550 ]]; then
        echo "✅ X-axis scaling is approximately 0.5x"
    fi
    
    if [[ $SCALE_Y_INT -ge 450 ]] && [[ $SCALE_Y_INT -le 550 ]]; then
        echo "✅ Y-axis scaling is approximately 0.5x"
    fi
    
    if [[ $SCALE_X_INT -eq $SCALE_Y_INT ]]; then
        echo "✅ Scaling is consistent across both axes"
        echo ""
        echo "Recommended scaling factor: $(echo "scale=2; 1 / $SCALE_X" | bc 2>/dev/null || echo "2.0")x"
        echo "  (Multiply coordinates by this factor before passing to ydotool)"
    fi
fi

echo ""
echo "=== Test Complete ==="


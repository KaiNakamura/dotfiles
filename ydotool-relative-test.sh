#!/bin/bash
# Test relative movement workaround from GitHub issue #250
# Workaround: Move to 0,0 first, then use relative movement

set -e

echo "=== Testing Relative Movement Workaround ==="
echo ""

if ! command -v ydotool &> /dev/null; then
    echo "ERROR: ydotool not installed"
    exit 1
fi

if ! pgrep -x ydotoold > /dev/null; then
    echo "ERROR: ydotoold daemon not running"
    exit 1
fi

echo "Monitor Layout:"
xrandr --listmonitors 2>/dev/null
echo ""

# Test 1: Workaround from GitHub issue - move to 0,0 first, then try absolute
# Theory: Moving to 0,0 resets coordinate system, then absolute moves work
echo "Test 1: Move to 0,0 then absolute to center of left monitor (DP-5)"
echo "Target: 960,540"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 0 0
sleep 0.1
ydotool mousemove 960 540
sleep 2

echo ""
echo "Test 2: Move to 0,0 then absolute to center of right monitor (HDMI-A-1)"
echo "Target: 2880,540"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 0 0
sleep 0.1
ydotool mousemove 2880 540
sleep 2

echo ""
echo "Test 3: Try with longer delay (0.05s as suggested in GitHub issue)"
echo "Target: center of laptop screen (eDP-1) - 1851,1680"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 0 0
sleep 0.05
ydotool mousemove 1851 1680
sleep 2

echo ""
echo "Test 4: Try moving to 0,0 then using screen-local coordinates"
echo "Assuming 0,0 is top-left of DP-5, try moving to center (960,540)"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 0 0
sleep 0.1
# If coordinate system resets, this should be relative to current screen
ydotool mousemove 960 540
sleep 2

echo ""
echo "Tests complete. Note where mouse actually moved."


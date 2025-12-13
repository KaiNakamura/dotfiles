#!/bin/bash
# Test script for ydotool coordinate behavior
# Tests different approaches to see what works

set -e

echo "=== ydotool Coordinate Testing ==="
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

# Test different coordinate approaches
echo "Test 1: Move to center of left monitor (DP-5) - coordinates 960,540"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 960 540
sleep 2

echo ""
echo "Test 2: Move to center of right monitor (HDMI-A-1) - coordinates 2880,540"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 2880 540
sleep 2

echo ""
echo "Test 3: Move to center of laptop screen (eDP-1) - coordinates 1851,1680"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 1851 1680
sleep 2

echo ""
echo "Test 4: Try with delay flag"
echo "Moving to 960,540 with delay in 2 seconds..."
sleep 2
ydotool mousemove --delay 0 960 540
sleep 2

echo ""
echo "Test 5: Try very small coordinates (10, 10)"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 10 10
sleep 2

echo ""
echo "Test 6: Try coordinates in middle range (1920, 1080)"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 1920 1080
sleep 2

echo ""
echo "Tests complete. Note where mouse actually moved for each test."

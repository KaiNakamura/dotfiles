#!/bin/bash
# Test script for ydotool v1.0.4 with new syntax
# Tests absolute and relative movement

set -e

export YDOTOOL_SOCKET=/tmp/.ydotool_socket

echo "=== Testing ydotool v1.0.4 ==="
echo ""

if ! command -v ydotool &> /dev/null; then
    echo "ERROR: ydotool not installed"
    exit 1
fi

if ! pgrep -x ydotoold > /dev/null; then
    echo "ERROR: ydotoold daemon not running"
    exit 1
fi

echo "ydotool version: $(ydotool --version 2>&1 || echo 'unknown')"
echo "ydotool path: $(which ydotool)"
echo ""

echo "Monitor Layout:"
xrandr --listmonitors 2>/dev/null || echo "xrandr not available"
echo ""

echo "=== Test 1: Absolute movement (new syntax) ==="
echo "Target: center of DP-5 (left monitor) - 960, 540"
echo "Command: ydotool mousemove --absolute -x 960 -y 540"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove --absolute -x 960 -y 540 2>&1
sleep 2
echo "Where did the mouse go?"
echo ""

echo "=== Test 2: Absolute movement (old syntax) ==="
echo "Target: center of DP-5 (left monitor) - 960, 540"
echo "Command: ydotool mousemove 960 540"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove 960 540 2>&1
sleep 2
echo "Where did the mouse go?"
echo ""

echo "=== Test 3: Relative movement ==="
echo "Moving relatively: +200, +200 pixels"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove -x 200 -y 200 2>&1
sleep 2
echo "Did it move 200 pixels right and down?"
echo ""

echo "=== Test 4: Move to 0,0 then relative ==="
echo "First moving to 0,0, then relative +960, +540"
echo "Moving in 2 seconds..."
sleep 2
ydotool mousemove --absolute -x 0 -y 0 2>&1
sleep 0.1
ydotool mousemove -x 960 -y 540 2>&1
sleep 2
echo "Where did the mouse go?"
echo ""

echo "Tests complete!"


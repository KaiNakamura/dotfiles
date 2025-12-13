#!/bin/bash
# Test script to verify ydotool mouse movement functionality

set -e

echo "=== ydotool Mouse Movement Test ==="
echo ""

# Check if ydotool is installed
if ! command -v ydotool &> /dev/null; then
    echo "❌ ERROR: ydotool is not installed"
    exit 1
fi
echo "✅ ydotool is installed: $(which ydotool)"

# Check if daemon is running
if ! pgrep -x ydotoold > /dev/null; then
    echo "⚠️  WARNING: ydotoold daemon is not running"
    echo "   Start it with: sudo systemctl start ydotoold"
    exit 1
fi
echo "✅ ydotoold daemon is running (PID: $(pgrep -x ydotoold))"

# Check group membership
if groups | grep -q "\binput\b"; then
    echo "✅ User is in 'input' group"
else
    echo "⚠️  WARNING: User is not in 'input' group"
    echo "   Add with: sudo usermod -aG input $USER"
    echo "   (Then log out and back in)"
fi

echo ""
echo "Testing mouse movement..."
echo "Moving mouse to (100, 100) in 2 seconds..."
sleep 2

# Test mouse movement
# Note: ydotool mousemove uses absolute coordinates by default
# Syntax: ydotool mousemove <x> <y>
# WARNING: There's a known bug on Wayland where absolute coordinates
# may not work correctly - the mouse may move to top-left instead
echo "Running: ydotool mousemove 100 100"
if ydotool mousemove 100 100 2>&1; then
    echo "✅ Mouse movement command executed successfully"
    echo ""
    echo "NOTE: On Wayland, ydotool may move mouse to top-left corner"
    echo "      instead of specified coordinates (known bug)."
    echo "      If the mouse moved at all, ydotool is working!"
else
    echo "❌ Mouse movement command failed"
    exit 1
fi




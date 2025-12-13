#!/bin/bash
# Investigation script for ydotool coordinate scaling issue
# Tests various coordinate scenarios to understand the 0.5x scaling behavior

set -e

export YDOTOOL_SOCKET=/tmp/.ydotool_socket

echo "=== ydotool Coordinate System Investigation ==="
echo ""
echo "System Information:"
echo "  ydotool version: $(ydotool --version 2>&1 || echo 'unknown')"
echo "  ydotoold running: $(pgrep -x ydotoold > /dev/null && echo 'yes' || echo 'no')"
echo ""

echo "Display Configuration:"
kscreen-doctor -o 2>/dev/null | grep -E "Output:|Geometry:|Scale:" | head -9
echo ""

echo "=== Test Scenarios ==="
echo ""
echo "This script will test various coordinate movements."
echo "Please observe where the cursor actually moves and compare with expected positions."
echo ""

# Test 1: Direct relative movement (without absolute to 0,0)
echo "Test 1: Direct relative movement from current position"
echo "  Command: ydotool mousemove -x 100 -y 100"
echo "  Expected: Move 100 pixels right and 100 pixels down from current position"
echo "  Moving in 3 seconds..."
sleep 3
ydotool mousemove -x 100 -y 100 2>&1
sleep 2
echo "  Where did the cursor move? (relative to starting position)"
echo ""

# Test 2: Absolute to 0,0 then relative (current workaround)
echo "Test 2: Absolute to (0,0) then relative movement (current workaround)"
echo "  Command: ydotool mousemove --absolute -x 0 -y 0 && ydotool mousemove -x 100 -y 100"
echo "  Expected: Move to top-left corner, then 100 pixels right and 100 pixels down"
echo "  Moving in 3 seconds..."
sleep 3
ydotool mousemove --absolute -x 0 -y 0 2>&1
sleep 0.1
ydotool mousemove -x 100 -y 100 2>&1
sleep 2
echo "  Where did the cursor move? (should be at 100, 100 in KWin coordinates)"
echo ""

# Test 3: Test with known working coordinate (480, 270 for left monitor center)
echo "Test 3: Known working coordinate (left monitor center)"
echo "  Command: ydotool mousemove --absolute -x 0 -y 0 && ydotool mousemove -x 480 -y 270"
echo "  Expected: Move to center of left monitor (DP-5) at (960, 540)"
echo "  Moving in 3 seconds..."
sleep 3
ydotool mousemove --absolute -x 0 -y 0 2>&1
sleep 0.1
ydotool mousemove -x 480 -y 270 2>&1
sleep 2
echo "  Did it reach the center of the left monitor?"
echo ""

# Test 4: Test with full coordinate (960, 540) to see actual position
echo "Test 4: Full coordinate test (should go to 2x target)"
echo "  Command: ydotool mousemove --absolute -x 0 -y 0 && ydotool mousemove -x 960 -y 540"
echo "  Expected: If 0.5x scaling, should go to (1920, 1080) - center of all screens"
echo "  Moving in 3 seconds..."
sleep 3
ydotool mousemove --absolute -x 0 -y 0 2>&1
sleep 0.1
ydotool mousemove -x 960 -y 540 2>&1
sleep 2
echo "  Where did the cursor move? (should be at center of all screens if 0.5x scaling)"
echo ""

# Test 5: Test relative movement from different starting positions
echo "Test 5: Relative movement from non-zero position"
echo "  First moving to (480, 270) using workaround..."
ydotool mousemove --absolute -x 0 -y 0 2>&1
sleep 0.1
ydotool mousemove -x 480 -y 270 2>&1
sleep 1
echo "  Now moving relatively +100, +100 from current position"
echo "  Command: ydotool mousemove -x 100 -y 100"
echo "  Expected: Move 100 pixels right and 100 pixels down"
echo "  Moving in 2 seconds..."
sleep 2
ydotool mousemove -x 100 -y 100 2>&1
sleep 2
echo "  Did it move exactly 100 pixels, or did it move 50 pixels (0.5x)?"
echo ""

echo "=== Investigation Complete ==="
echo ""
echo "Key Questions:"
echo "  1. Does relative movement ALWAYS use 0.5x scaling, or only after absolute (0,0)?"
echo "  2. Is the scaling consistent regardless of starting position?"
echo "  3. Does the scaling apply to both X and Y axes equally?"


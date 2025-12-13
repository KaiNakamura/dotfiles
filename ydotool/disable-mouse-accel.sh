#!/bin/bash
# Temporarily disable mouse acceleration for ydotool absolute movement
# This is required for ydotool mousemove --absolute to work correctly

set -e

echo "=== Disabling Mouse Acceleration for ydotool ==="
echo ""

# Get current acceleration value
CURRENT_ACCEL=$(kreadconfig5 --file kcminputrc --group Mouse --key XLbInptPointerAcceleration 2>/dev/null || echo "0.2")

echo "Current mouse acceleration: $CURRENT_ACCEL"
echo ""

if [ "$CURRENT_ACCEL" != "0" ] && [ "$CURRENT_ACCEL" != "-1" ]; then
    echo "Disabling mouse acceleration (setting to 0)..."
    kwriteconfig5 --file kcminputrc --group Mouse --key XLbInptPointerAcceleration 0
    
    # Also ensure flat profile is enabled
    kwriteconfig5 --file kcminputrc --group Mouse --key X11LibInputXAccelProfileFlat true
    
    echo "✅ Mouse acceleration disabled"
    echo ""
    echo "NOTE: You may need to restart KWin or log out/in for changes to take effect."
    echo "      Or run: qdbus org.kde.KWin /KWin reconfigure"
    echo ""
    echo "To restore acceleration later, run:"
    echo "  kwriteconfig5 --file kcminputrc --group Mouse --key XLbInptPointerAcceleration $CURRENT_ACCEL"
else
    echo "✅ Mouse acceleration is already disabled (value: $CURRENT_ACCEL)"
fi

echo ""
echo "Testing ydotool with disabled acceleration..."
echo "Run: ydotool mousemove --absolute -x 100 -y 100"


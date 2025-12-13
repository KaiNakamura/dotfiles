#!/bin/bash
# Apply udev rule for uinput device permissions

set -e

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Applying uinput udev rule ==="
echo ""

# Copy udev rule
echo "1. Copying udev rule..."
sudo cp "$WORKDIR/99-uinput.rules" /etc/udev/rules.d/99-uinput.rules

# Reload udev rules
echo "2. Reloading udev rules..."
sudo udevadm control --reload-rules

# Trigger the rule
echo "3. Triggering udev rule..."
sudo udevadm trigger

# Verify permissions
echo "4. Verifying permissions..."
ls -la /dev/uinput

# Restart daemon
echo "5. Restarting ydotoold daemon..."
sudo systemctl restart ydotoold

echo ""
echo "✅ Done! You can now test with: ./ydotool-test.sh"



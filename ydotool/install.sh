#!/bin/bash

# Exit on error
set -e

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install ydotool package
sudo apt update
sudo apt install -y ydotool

# Add user to input group
echo "Adding user to input group..."
sudo usermod -aG input "$USER"
echo "WARNING: Please log out and back in for group changes to take effect"

# Copy service file
sudo cp "$WORKDIR/ydotoold.service" /etc/systemd/system/

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable ydotoold
sudo systemctl start ydotoold

echo "ydotoold daemon started"


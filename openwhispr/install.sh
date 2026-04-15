#!/bin/bash

set -e

OPENWHISPR_VERSION="1.6.8"

# Check if already installed
if command -v openwhispr &>/dev/null || dpkg -l openwhispr 2>/dev/null | grep -q "^ii"; then
    echo "OpenWhispr is already installed, skipping download..."
else
    echo "Downloading OpenWhispr ${OPENWHISPR_VERSION}..."

    URL="https://github.com/OpenWhispr/openwhispr/releases/download/v${OPENWHISPR_VERSION}/OpenWhispr-${OPENWHISPR_VERSION}-linux-amd64.deb"

    TMP_DEB=$(mktemp --suffix=.deb)
    curl -L "$URL" -o "$TMP_DEB"

    echo "Installing OpenWhispr..."
    sudo dpkg -i "$TMP_DEB"
    rm -f "$TMP_DEB"

    echo "OpenWhispr installed."
fi

echo "OpenWhispr setup complete."

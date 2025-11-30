#!/bin/bash

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install btop
brew install btop

# Create btop config directory
mkdir -p ~/.config/btop/themes

# Copy btop.conf
if [[ -f "$WORKDIR/btop.conf" ]]; then
    cp "$WORKDIR/btop.conf" ~/.config/btop/btop.conf
    echo "btop.conf copied to ~/.config/btop/"
fi

# Copy theme file
if [[ -f "$WORKDIR/themes/kai.theme" ]]; then
    cp "$WORKDIR/themes/kai.theme" ~/.config/btop/themes/kai.theme
    echo "kai.theme copied to ~/.config/btop/themes/"
fi


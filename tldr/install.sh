#!/bin/bash

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install tealdeer (tldr)
brew install tealdeer

# Create tealdeer config directory
mkdir -p ~/.config/tealdeer

# Copy config.toml
if [[ -f "$WORKDIR/config.toml" ]]; then
    cp "$WORKDIR/config.toml" ~/.config/tealdeer/config.toml
    echo "tealdeer config.toml copied to ~/.config/tealdeer/"
fi


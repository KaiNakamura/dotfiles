#!/bin/bash

# Install Starship
curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Copy starship.toml
cp ./starship.toml ~/.config/starship.toml

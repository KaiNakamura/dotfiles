#!/bin/bash

# Install Starship
curl -sS https://starship.rs/install.sh | sh

# Update ~/.zshrc
# TODO: Move to zshrc module
echo >> ~/.zshrc
echo 'eval "$(starship init zsh)"' >> ~/.zshrc

# Copy starship.tomp
cp ./starship.toml ~/.config/starship.toml

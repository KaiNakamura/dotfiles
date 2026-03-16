#!/bin/bash

# Install Starship
curl -sS https://starship.rs/install.sh | sh -s -- --yes

cp ./starship.toml ~/.config/starship.toml

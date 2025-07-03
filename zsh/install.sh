#!/bin/bash

# Install zsh
sudo apt install -y zsh

# Make zsh default
chsh -s $(which zsh)

# Install Oh My Zsh!
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"


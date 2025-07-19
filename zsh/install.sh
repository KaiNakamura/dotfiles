#!/bin/bash

# TODO: Add support for non-apt
# Install zsh
# sudo apt install -y zsh

# Arch
# sudo pacman -S zsh

# Make zsh default
chsh -s $(which zsh)

# Check if Oh My Zsh is already installed
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh is already installed. Updating..."
    # Update existing Oh My Zsh installation
    cd "$HOME/.oh-my-zsh"
    git pull origin master
    cd - > /dev/null
else
    # Install Oh My Zsh!
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# TODO: Update .zshrc but don't overwrite existing
# (haven't figured out how not to do this yet)
# Also this one may not be cd ing correctly?

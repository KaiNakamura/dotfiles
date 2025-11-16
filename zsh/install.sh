#!/bin/bash

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install zsh
sudo apt install -y zsh

# Check if Oh My Zsh is already installed
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh is already installed. Updating..."
    # Update existing Oh My Zsh installation
    cd "$HOME/.oh-my-zsh"
    git pull origin master
    cd - > /dev/null
else
    # Install Oh My Zsh!
    # Use RUNZSH=no to prevent it from launching zsh
    # Use KEEP_ZSHRC=yes to preserve existing .zshrc
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Setup .zshrc paths
zshrc_source="$WORKDIR/.zshrc"
zshrc_target="$HOME/.zshrc"

if [[ ! -f "$zshrc_source" ]]; then
    echo "Warning: No .zshrc found in zsh module, skipping symlink"
else
    # Backup existing .zshrc if it exists
    if [[ -e "$zshrc_target" ]]; then
        echo "Backing up existing .zshrc to ${zshrc_target}.bak"
        cp -L "$zshrc_target" "${zshrc_target}.bak"
    fi
    
    # Create symlink
    ln -sf "$zshrc_source" "$zshrc_target"
    echo ".zshrc symlinked to dotfiles"
fi

# Change default shell to zsh
if command -v zsh &> /dev/null; then
    ZSH_PATH=$(which zsh)
    ACTUAL_USER="${SUDO_USER:-$USER}"
    CURRENT_SHELL=$(getent passwd "$ACTUAL_USER" 2>/dev/null | cut -d: -f7)
    
    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        echo "Changing default shell to zsh..."
        sudo chsh -s "$ZSH_PATH" "$ACTUAL_USER"
    fi
fi

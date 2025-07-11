#!/bin/bash

# Install some dependencies
sudo apt install -y \
	make \
	unzip \
	gcc \
	fd-find \
	fonts-noto-color-emoji \
	xclip

# Install ripgrep
brew install ripgrep

# Install nvim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
rm -f nvim-linux-x86_64.tar.gz

# Setup kai.nvim config
REPO_DIR="$HOME/repos/kai.nvim"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

# Ensure repos directory exists
mkdir -p "$HOME/repos"

# Clone or update kai.nvim repo
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning kai.nvim..."
    git clone https://github.com/KaiNakamura/kai.nvim.git "$REPO_DIR"
else
    echo "Updating kai.nvim..."
    cd "$REPO_DIR"
    git checkout main
    git pull origin main
    cd - > /dev/null
fi

# Copy config to nvim config directory
echo "Installing nvim config..."
rm -rf "$CONFIG_DIR"
cp -r "$REPO_DIR" "$CONFIG_DIR"

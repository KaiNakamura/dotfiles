#!/bin/bash

# TODO: Add support for non-apt
# Install some dependencies
# sudo apt install -y \
# 	make \
# 	unzip \
# 	gcc \
# 	fd-find \
# 	fonts-noto-color-emoji \
# 	xclip \
# 	wl-clipboard

# Arch
# sudo pacman -S fd wl-clipboard

# Install ripgrep
brew install ripgrep

# Install nvim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
rm -f nvim-linux-x86_64.tar.gz

# Setup kai.nvim config
REPO_DIR="$HOME/repos/kai.nvim"
CONFIG_DIR="$HOME/.config/nvim"

# Ensure repos directory exists
mkdir -p "$HOME/repos"

# Clone or update kai.nvim repo
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning kai.nvim..."
    git clone https://github.com/KaiNakamura/kai.nvim.git "$REPO_DIR"
else
    echo "Updating kai.nvim..."
    cd "$REPO_DIR"
    git checkout master
    git pull origin master
    cd - > /dev/null
fi

# Create symlink for nvim config
echo "Creating symlink for nvim config..."
rm -rf "$CONFIG_DIR"
ln -sf "$REPO_DIR" "$CONFIG_DIR"

#!/bin/bash

# Install ripgrep
brew install ripgrep

# Check if nvim is already installed
if command -v nvim &> /dev/null && nvim --version &> /dev/null; then
    echo "Neovim is already installed, skipping installation..."
else
    # Install nvim
    TMP_TAR=$(mktemp)
    curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz -o "$TMP_TAR"
    sudo rm -rf /opt/nvim
    sudo tar -C /opt -xzf "$TMP_TAR"
    rm -f "$TMP_TAR"
fi

# Setup kai.nvim config
REPO_DIR="$HOME/repos/kai.nvim"
CONFIG_DIR="$HOME/.config/nvim"

# Ensure repos directory exists
mkdir -p "$HOME/repos"

# Clone or update kai.nvim repo
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning kai.nvim..."
    git -c "url.https://github.com/KaiNakamura/.insteadOf=https://github.com/KaiNakamura/" \
      clone https://github.com/KaiNakamura/kai.nvim.git "$REPO_DIR"
    git -C "$REPO_DIR" config \
      "url.https://github.com/KaiNakamura/.insteadOf" \
      "https://github.com/KaiNakamura/"
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

#!/bin/bash
set -euo pipefail

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

# Make nvim available on PATH via ~/.local/bin
mkdir -p "$HOME/.local/bin"
ln -sf /opt/nvim-linux-x86_64/bin/nvim "$HOME/.local/bin/nvim"

# Setup kai.nvim config
REPO_DIR="$HOME/repos/kai.nvim"
CONFIG_DIR="$HOME/.config/nvim"

# Ensure repos directory exists
mkdir -p "$HOME/repos"

# Clone or update kai.nvim repo.
#
# kai.nvim is public, so anonymous HTTPS to github.com works without creds.
# The workspace's global ~/.gitconfig pulls in .gitconfig.coder, which stacks
# insteadOf rules (cyvl proxy bypass + owner-scoped SSH redirects). Past iters
# tried to beat those rules with longer-prefix escape hatches; round-6 ended up
# tying iter-04's rule and the SSH redirect won, breaking the clone. Instead of
# entering that competition, isolate this one git process from the global rule
# stack: GIT_CONFIG_GLOBAL=/dev/null (and SYSTEM for safety) means git sees no
# insteadOf rules at all and uses the URL literally. Future changes to
# .gitconfig.coder cannot affect this clone.
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning kai.nvim..."
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      git clone https://github.com/KaiNakamura/kai.nvim.git "$REPO_DIR"
else
    echo "Updating kai.nvim..."
    cd "$REPO_DIR"
    # Same isolation as the clone branch: keep update immune to global rewrites
    # so re-runs of the dotfiles install never depend on auth state.
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git checkout master
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git pull origin master
    cd - > /dev/null
fi

# Create symlink for nvim config
echo "Creating symlink for nvim config..."
rm -rf "$CONFIG_DIR"
ln -sf "$REPO_DIR" "$CONFIG_DIR"

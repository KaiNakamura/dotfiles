#!/bin/bash

# Install fzf
brew install fzf

# Install fzf key bindings and fuzzy completion (non-interactive)
# This creates ~/.fzf.zsh which is sourced in .zshrc
# Use yes to answer prompts non-interactively, or check if already installed
if [[ -f ~/.fzf.zsh ]]; then
    echo "fzf key bindings already installed"
else
    yes | $(brew --prefix)/opt/fzf/install --all --no-update-rc 2>/dev/null || true
fi


#!/bin/bash

source "$(dirname "$0")/../lib/profile.sh"

if [[ "$DOTFILES_PROFILE" == "coder" || "$DOTFILES_PROFILE" == "grok" ]]; then
    # Coder/Grok boxes may already have identity set elsewhere.
    # Layer non-identity settings via include.path so identity survives.
    cp "./.gitconfig.${DOTFILES_PROFILE}" ~/.gitconfig-personal
    git config --global include.path '~/.gitconfig-personal'
    cp ./.gitignore_global ~/.gitignore_global
else
    cp ./.gitconfig ~/.gitconfig
    cp ./.gitignore_global ~/.gitignore_global
fi

#!/bin/bash

source "$(dirname "$0")/../lib/profile.sh"

if [[ "$DOTFILES_PROFILE" == "coder" ]]; then
    # Cyvl Coder workspaces set work identity in ~/.gitconfig via other tooling.
    # Layer non-identity settings on via include.path so identity survives.
    cp ./.gitconfig.coder ~/.gitconfig-personal
    git config --global include.path '~/.gitconfig-personal'
    cp ./.gitignore_global ~/.gitignore_global
else
    cp ./.gitconfig ~/.gitconfig
    cp ./.gitignore_global ~/.gitignore_global
fi

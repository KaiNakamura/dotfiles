#!/bin/bash

source "$(dirname "$0")/../lib/profile.sh"

if [[ "$DOTFILES_PROFILE" == "coder" ]]; then
    # Cyvl Coder workspaces set work identity via other tooling; preserve it.
    # Apply only non-identity settings via additive `git config --global` calls.
    git config --global core.editor vim
    git config --global core.excludesFile '~/.gitignore_global'
    git config --global url."ssh://git@github.com".insteadOf https://github.com
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global pager.branch false
    git config --global delta.navigate true
    git config --global delta.side-by-side true
    git config --global delta.line-numbers true
    cp ./.gitignore_global ~/.gitignore_global
else
    cp ./.gitconfig ~/.gitconfig
    cp ./.gitignore_global ~/.gitignore_global
fi

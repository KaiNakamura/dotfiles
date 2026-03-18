#!/bin/bash
DOTFILES_PROFILE=$(cat ~/.dotfiles-profile 2>/dev/null || echo "home")
export DOTFILES_PROFILE

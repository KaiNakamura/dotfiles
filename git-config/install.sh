#!/bin/sh
set -e
DOTFILES_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/profile.sh
. "$DOTFILES_ROOT/lib/profile.sh"
# shellcheck source=../lib/asset.sh
. "$DOTFILES_ROOT/lib/asset.sh"

src=$(resolve_asset ./.gitconfig)
cp ./.gitignore_global ~/.gitignore_global

case $PROFILE_GIT_MODE in
    include)
        cp "$src" ~/.gitconfig-personal
        git config --global include.path '~/.gitconfig-personal'
        ;;
    *)
        cp "$src" ~/.gitconfig
        ;;
esac

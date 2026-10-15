#!/bin/sh
set -e
DOTFILES_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/profile.sh
. "$DOTFILES_ROOT/lib/profile.sh"
# shellcheck source=../lib/asset.sh
. "$DOTFILES_ROOT/lib/asset.sh"

curl -sS https://starship.rs/install.sh | sh -s -- --yes

mkdir -p "$HOME/.config"
src=$(resolve_asset ./starship.toml)
cp "$src" "$HOME/.config/starship.toml"
echo "starship: copied $src -> ~/.config/starship.toml"

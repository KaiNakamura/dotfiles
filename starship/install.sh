#!/bin/bash

# Install Starship
curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Pick toml by profile: ~/.dotfiles-profile is written by the orchestrator
# install.sh from --profile <name>. Fall back to starship.toml.
profile=""
[ -f "$HOME/.dotfiles-profile" ] && profile="$(cat "$HOME/.dotfiles-profile")"

src="./starship.toml"
if [ -n "$profile" ] && [ -f "./starship.${profile}.toml" ]; then
    src="./starship.${profile}.toml"
elif [ "$profile" = "grok" ] && [ -f "./starship.coder.toml" ]; then
    # Reuse coder prompt; no separate grok toml to keep in sync.
    src="./starship.coder.toml"
fi

cp "$src" "$HOME/.config/starship.toml"
echo "starship: copied $src -> ~/.config/starship.toml"

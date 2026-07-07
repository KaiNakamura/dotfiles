#!/bin/bash
# brew module: bootstraps Homebrew.
#
# Many modules (bat, btop, delta, eza, fd, fzf, tldr, aws, worktrunk, nvim)
# install their tools via `brew`. On a fresh headless box (e.g. a Coder
# workspace built from codercom/enterprise-base:ubuntu) brew is absent, so this
# module installs it first. Idempotent: no-op if brew is already on PATH.
#
# Note: the parent install.sh also sources brew's shellenv into its own
# environment right after this module runs, so later modules in the same run
# can see `brew` (each module runs in a subshell and cannot mutate the parent).

set -e

# Standard Homebrew-on-Linux prefix.
BREW_PREFIX="/home/linuxbrew/.linuxbrew"

if command -v brew >/dev/null 2>&1; then
    echo "brew: already installed ($(command -v brew))"
    exit 0
fi

if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
    echo "brew: found at $BREW_PREFIX/bin/brew, not on PATH yet"
    eval "$("$BREW_PREFIX/bin/brew" shellenv)"
    exit 0
fi

# Homebrew's installer needs curl, git, and build tools.
if command -v apt-get >/dev/null 2>&1; then
    echo "brew: installing prerequisites (curl, git, build-essential)"
    sudo apt-get update -y
    sudo apt-get install -y build-essential procps curl file git
fi

echo "brew: running Homebrew installer (non-interactive)"
NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Persist brew on PATH for future login shells (bash + zsh).
shellenv_line="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [[ -f "$rc" ]] && ! grep -qF "$BREW_PREFIX/bin/brew shellenv" "$rc"; then
        printf '\n# Homebrew\n%s\n' "$shellenv_line" >> "$rc"
    fi
done

# Make brew usable for the rest of THIS module (parent handles the rest).
eval "$("$BREW_PREFIX/bin/brew" shellenv)"

echo "brew: installed at $(command -v brew)"

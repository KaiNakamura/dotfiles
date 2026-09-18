#!/bin/bash
# The `th` thoughts vault CLI, plus the desktop-side helpers that go with it.
#
# th lives in its own repo and is installed from there, since it is a Rust
# binary and no package manager carries it. What lives here besides is the part
# th deliberately leaves out: the KDE and KWin knowledge that turns a list of
# agents into a list of windows. th itself stays portable and works over ssh on
# a box with no display, which is why the two halves are installed separately.

set -e

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="$HOME/.local/bin"
TH_REPO="https://github.com/KaiNakamura/th"

# Rust is this module's prerequisite the way brew is elsewhere, so install it
# rather than skipping: an explicit `./install.sh th` bypasses the profile
# ordering, so nothing else is going to put cargo there first. rustup is left to
# amend the shell profiles itself, since which one is in play differs per box
# (the Coder workspaces source their bash init from another repo entirely).
if ! command -v cargo > /dev/null 2>&1; then
    echo "  Installing: rust (prerequisite for th)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
fi

echo "  Installing: th"
cargo install --git "$TH_REPO"

# The helpers below drive KWin over D-Bus, so they are meaningless anywhere
# else. th is already in by this point and works without them.
if [[ "${XDG_CURRENT_DESKTOP:-}" != *"KDE"* ]]; then
    echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Skipping th desktop helpers (KDE not detected)"
    exit 0
fi

mkdir -p "$TARGET_BIN"
for script in "$WORKDIR"/bin/*; do
    name=$(basename "$script")
    echo "  Installing: $name"
    cp "$script" "$TARGET_BIN/$name"
    chmod +x "$TARGET_BIN/$name"
done

echo "Done."

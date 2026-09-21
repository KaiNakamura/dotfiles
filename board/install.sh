#!/bin/bash
# The board: a kanban view of the thoughts vault.
#
# Installed as a plain script rather than a systemd service, because the board
# is something to open when you want it, not a thing that should be running.
# It reads the vault through `th`, so the th module installs first.

set -e

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="$HOME/.local/bin"

mkdir -p "$TARGET_BIN"
echo "  Installing: board"
cp "$WORKDIR/board.py" "$TARGET_BIN/board"
chmod +x "$TARGET_BIN/board"

if ! command -v th > /dev/null 2>&1; then
    echo "Note: th is not on PATH, so the board has nothing to read yet."
    echo "It is installed by the th module."
fi

echo "Done."

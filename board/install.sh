#!/bin/bash
# The board: a kanban view of the thoughts vault.
#
# It lives in the th repo beside th itself, and is installed from a fresh clone
# of it. It reads the vault through `th`, so the th module installs first.

set -e

TH_REPO="https://github.com/KaiNakamura/th"

if ! command -v git > /dev/null 2>&1; then
    echo "Note: git is not on PATH, so the board was skipped."
    exit 0
fi

SRC="$(mktemp -d)"
trap 'rm -rf "$SRC"' EXIT
git clone --quiet --depth 1 "$TH_REPO" "$SRC"
bash "$SRC/board/install.sh"

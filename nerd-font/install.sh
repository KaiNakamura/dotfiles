#!/bin/bash

# Install Noto Nerd Font
FONT_DIR="$HOME/.local/share/fonts"
ZIP_PATH="$FONT_DIR/Noto.zip"
ZIP_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Noto.zip"

mkdir -p "$FONT_DIR"
curl -L "$ZIP_URL" -o "$ZIP_PATH"
unzip -o "$ZIP_PATH" -d "$FONT_DIR"
rm "$ZIP_PATH"
fc-cache -fv

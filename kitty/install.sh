#!/bin/bash

# Install kitty
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

# Copy .kitty.conf
mkdir -p ~/.config/kitty
cp ./kitty.conf ~/.config/kitty/kitty.conf
#!/bin/bash

# TODO: Add support for non-apt
# Install Vim with GTK3 (for clipboard support)
sudo apt install -y vim-gtk3

# Copy .vimrc
cp ./.vimrc ~/.vimrc

#!/bin/bash

set -e

# Synthetic keys on Wayland; voxtype pastes through it on KDE
VERSION="1.0.4"
WORKDIR="$(cd -- "$(dirname "$0")" && pwd)"

# Ubuntu ships 0.1.8; voxtype speaks the 1.x key syntax
if ! [ -x /usr/local/bin/ydotoold ]; then
    dpkg -s cmake g++ >/dev/null 2>&1 || sudo apt install -y cmake g++
    src="$(mktemp -d)"
    git clone -q --depth 1 --branch "v$VERSION" https://github.com/ReimuNotMoe/ydotool "$src"
    # scdoc is only needed for the man pages, so build just the binaries
    cmake -S "$src" -B "$src/build" >/dev/null
    make -C "$src/build" ydotool ydotoold >/dev/null
    sudo install -m 755 "$src/build/ydotool" "$src/build/ydotoold" /usr/local/bin/
    rm -rf "$src"
fi

# ydotoold runs as the user, so /dev/uinput has to be writable by the input group
RULE=/etc/udev/rules.d/60-uinput.rules
if ! [ -f "$RULE" ]; then
    echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' | sudo tee "$RULE" >/dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger --name-match=uinput
fi
id -nG | grep -qw input || sudo usermod -aG input "$USER"

mkdir -p "$HOME/.config/systemd/user"
cp "$WORKDIR/ydotoold.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable ydotoold >/dev/null 2>&1
systemctl --user restart ydotoold

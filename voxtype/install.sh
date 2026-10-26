#!/bin/bash

set -e

# Offline dictation: tap Right Alt to start, tap again to paste the transcript
VERSION="1.1.1"

installed=$(dpkg-query -W -f='${Version}' voxtype 2>/dev/null || true)
if [ "$installed" != "$VERSION-1" ]; then
    deb="$(mktemp -d)/voxtype.deb"
    curl -fsSL -o "$deb" "https://github.com/peteonrails/voxtype/releases/download/v$VERSION/voxtype_${VERSION}-1_amd64.deb"
    sudo apt install -y "$deb"
    rm -f "$deb"
fi

mkdir -p "$HOME/.config/voxtype"
cp "$(cd -- "$(dirname "$0")" && pwd)/config.toml" "$HOME/.config/voxtype/config.toml"

# The turbo model needs a GPU to keep up; base.en runs fine on CPU
DROPIN="$HOME/.config/systemd/user/voxtype.service.d/gpu.conf"
if command -v nvidia-smi >/dev/null; then
    mkdir -p "$(dirname "$DROPIN")"
    printf '[Service]\nEnvironment="VOXTYPE_GPU=1"\nEnvironment="VOXTYPE_VULKAN_DEVICE=nvidia"\n' > "$DROPIN"
else
    voxtype config set whisper.model base.en >/dev/null
    rm -f "$DROPIN"
fi
voxtype setup --download --model "$(voxtype config get whisper.model)" --quiet

[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/.ydotool_socket" ] \
    || echo "  Warning: ydotoold isn't running; Voxtype will leave transcripts on the clipboard"

voxtype setup systemd >/dev/null
systemctl --user daemon-reload
systemctl --user enable voxtype >/dev/null 2>&1
systemctl --user restart voxtype

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

# The turbo model needs a GPU to keep up; base.en runs fine on CPU
DROPIN="$HOME/.config/systemd/user/voxtype.service.d/gpu.conf"
if command -v nvidia-smi >/dev/null; then
    model="large-v3-turbo"
    mkdir -p "$(dirname "$DROPIN")"
    printf '[Service]\nEnvironment="VOXTYPE_GPU=1"\nEnvironment="VOXTYPE_VULKAN_DEVICE=nvidia"\n' > "$DROPIN"
else
    model="base.en"
    rm -f "$DROPIN"
fi
voxtype setup --download --model "$model" --quiet

set_key() { voxtype config set "$1" "$2" >/dev/null; }
set_key whisper.model "$model"
set_key whisper.initial_prompt "Voxtype, Claude Code, Kai, Cyvl, Pitstop, Supabase, kitty, KDE, dotfiles."
set_key hotkey.key RIGHTALT
set_key hotkey.mode toggle
set_key audio.max_duration_secs 300
set_key audio.feedback.enabled true
set_key audio.feedback.theme subtle
# wtype can't type on KDE; paste goes through ydotool, and kitty pastes on ctrl+shift+v
set_key output.mode paste
set_key output.paste_keys ctrl+shift+v
set_key output.notification.on_recording_start true
# The OSD needs gtk4-layer-shell, which Ubuntu 24.04 doesn't ship
set_key osd.enabled false

[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/.ydotool_socket" ] \
    || echo "  Warning: ydotoold isn't running; Voxtype will leave transcripts on the clipboard"

voxtype setup systemd >/dev/null
systemctl --user daemon-reload
systemctl --user enable voxtype >/dev/null 2>&1
systemctl --user restart voxtype

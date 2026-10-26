#!/bin/bash

set -e

# Offline dictation: hold Right Alt to talk
TAG="v0.18.4"
CONFIG="$HOME/.config/vocalinux/config.json"

installed=$("$HOME/.local/bin/vocalinux" --version 2>/dev/null | tail -1 | awk '{print $2}' || true)
if [ "v$installed" != "$TAG" ]; then
    script="$(mktemp)"
    curl -fsSL "https://raw.githubusercontent.com/VocaHQ/vocalinux/$TAG/install.sh" -o "$script"
    # A private index in pip.conf 401s once its token expires
    PIP_INDEX_URL=https://pypi.org/simple bash "$script" --tag="$TAG" --auto
    rm -f "$script"
fi

# Kitty pastes on ctrl+shift+v; the overlay steals focus on KDE Wayland
mkdir -p "$(dirname "$CONFIG")"
python3 - "$CONFIG" <<'EOF'
import json, os, sys
path = sys.argv[1]
config = json.load(open(path)) if os.path.exists(path) else {}
config.setdefault("text_injection", {})["paste_shortcut"] = "ctrl+shift+v"
config.setdefault("ui", {})["show_overlay"] = False
json.dump(config, open(path, "w"), indent=4)
EOF

#!/bin/sh
# The `th` thoughts vault CLI, plus optional KDE helpers.
set -e

WORKDIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
TARGET_BIN="$HOME/.local/bin"
TH_REPO="https://github.com/KaiNakamura/th"

if ! command -v cargo >/dev/null 2>&1; then
    echo "  Installing: rust (prerequisite for th)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Prefer rustup's toolchain over any older system rustc (e.g. Debian's).
# shellcheck disable=SC1091
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
export PATH="$HOME/.cargo/bin:$PATH"

# Fetch git deps with the git CLI so gh HTTPS credentials apply (private repos).
mkdir -p "$HOME/.cargo"
if [ -f "$HOME/.cargo/config.toml" ]; then
    if ! grep -q 'git-fetch-with-cli' "$HOME/.cargo/config.toml" 2>/dev/null; then
        printf '\n[net]\ngit-fetch-with-cli = true\n' >> "$HOME/.cargo/config.toml"
    fi
else
    printf '[net]\ngit-fetch-with-cli = true\n' > "$HOME/.cargo/config.toml"
fi
# Point git at gh's credential helper when available (no tokens in the script).
if command -v gh >/dev/null 2>&1; then
    gh auth setup-git >/dev/null 2>&1 || true
fi
export CARGO_NET_GIT_FETCH_WITH_CLI=true

echo "  Installing: th"
if ! cargo install --git "$TH_REPO"; then
    echo "  cargo --git failed; cloning via gh and installing from path"
    TH_SRC="${TH_SRC:-$HOME/repos/th}"
    mkdir -p "$(dirname "$TH_SRC")"
    if [ ! -d "$TH_SRC/.git" ]; then
        gh repo clone KaiNakamura/th "$TH_SRC"
    else
        git -C "$TH_SRC" pull --ff-only || true
    fi
    cargo install --path "$TH_SRC"
fi

# KWin helpers only on KDE.
case ${XDG_CURRENT_DESKTOP:-} in
    *KDE*) ;;
    *)
        echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
        echo "Skipping th desktop helpers (KDE not detected)"
        exit 0
        ;;
esac

mkdir -p "$TARGET_BIN"
for script in "$WORKDIR"/bin/*; do
    [ -f "$script" ] || continue
    name=$(basename "$script")
    echo "  Installing: $name"
    cp "$script" "$TARGET_BIN/$name"
    chmod +x "$TARGET_BIN/$name"
done

# kwin-window-list prints what this pair keeps current: a KWin script that
# stays loaded and publishes every window change, and the D-Bus service that
# writes what it publishes to a file.
echo "  Installing: window-list service"
SERVICE_DST="$TARGET_BIN/window-list-service.py"
mkdir -p "$HOME/.local/share/dbus-1/services" "$HOME/.config/systemd/user"
cp "$WORKDIR/scripts/window-list-service.py" "$SERVICE_DST"
chmod +x "$SERVICE_DST"
cat > "$HOME/.local/share/dbus-1/services/org.hjkl.WindowList.service" << EOF
[D-BUS Service]
Name=org.hjkl.WindowList
Exec=/usr/bin/python3 $SERVICE_DST
SystemdService=window-list.service
EOF
cp "$WORKDIR/systemd/window-list.service" "$HOME/.config/systemd/user/window-list.service"
systemctl --user daemon-reload
systemctl --user enable window-list.service
# A copy already running holds the old code until it is restarted.
systemctl --user restart window-list.service

echo "  Installing: window-list-publisher KWin script"
if command -v kpackagetool6 > /dev/null 2>&1; then
    KPKG=kpackagetool6
    KWRITECONFIG=kwriteconfig6
else
    KPKG=kpackagetool5
    KWRITECONFIG=kwriteconfig5
fi
"$KPKG" --type KWin/Script -r window-list-publisher > /dev/null 2>&1 || true
"$KPKG" --type KWin/Script -i "$WORKDIR/kwin-scripts/window-list-publisher"
# Toggled off then on, so a KWin already running drops the old copy and loads
# this one.
"$KWRITECONFIG" --file kwinrc --group Plugins --key window-list-publisherEnabled false
qdbus org.kde.KWin /KWin reconfigure
"$KWRITECONFIG" --file kwinrc --group Plugins --key window-list-publisherEnabled true
qdbus org.kde.KWin /KWin reconfigure

echo "Done."

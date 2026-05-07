#!/bin/bash
# Clean stale X lock files from previous runs.
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null

# Virtual display so Electron-based Obsidian can run headless.
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
export DISPLAY=:99
sleep 2

# Forward CDP port to 0.0.0.0 so the host can reach it for IPC/CLI.
socat TCP-LISTEN:9223,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:9222 &

# Wait for the vault to exist before starting Obsidian. The host bind-mounts
# the vault's parent (e.g. ~/repos -> /vault), but the vault itself may be
# cloned interactively by the user after this container is already running.
# Obsidian opens the vault once at startup and does not auto-rescan, so
# launching it before the vault appears means the CLI returns "Vault not
# found" until restart. Sleeping here keeps the container in "starting"
# until the vault is real, then exec's Obsidian which loads the vault for
# its lifetime.
if [[ -n "${OBSIDIAN_VAULT_PATH:-}" ]]; then
    while [[ ! -d "$OBSIDIAN_VAULT_PATH" ]]; do
        echo "obsidian: waiting for vault at $OBSIDIAN_VAULT_PATH ..."
        sleep 5
    done
    echo "obsidian: vault present at $OBSIDIAN_VAULT_PATH; starting"
fi

exec /opt/obsidian/obsidian --no-sandbox --disable-gpu --remote-debugging-port=9222 "$@"

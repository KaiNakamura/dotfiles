#!/bin/bash
# Clean stale X lock files from previous runs.
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null

# Virtual display so Electron-based Obsidian can run headless.
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
export DISPLAY=:99
sleep 2

# Forward CDP port to 0.0.0.0 so the host can reach it for IPC/CLI.
socat TCP-LISTEN:9223,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:9222 &

exec /opt/obsidian/obsidian --no-sandbox --disable-gpu --remote-debugging-port=9222 "$@"

#!/bin/sh
# Run inside WSL: registers and starts the keepalive task from keepalive.ps1. See docs/wsl.md.
set -e

if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    echo "wsl: not running under WSL, skipping"
    exit 0
fi

PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
here="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

# PowerShell won't run a script from a \\wsl.localhost path reliably; copy it to %TEMP%.
win_tmp="$(cd /mnt/c && "$PS" -NoProfile -Command '[IO.Path]::GetTempPath()' | tr -d '\r')"
cp "$here/keepalive.ps1" "$(wslpath -u "$win_tmp")wsl-keepalive.ps1"
(cd /mnt/c && "$PS" -NoProfile -ExecutionPolicy Bypass \
    -File "${win_tmp}wsl-keepalive.ps1" -Start "$@")
rm -f "$(wslpath -u "$win_tmp")wsl-keepalive.ps1"

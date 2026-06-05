#!/bin/bash
# tailscale module: installs tailscale and enables the tailscaled daemon.
#
# Login is intentionally NOT automated: machines may belong to different
# tailnets (personal vs work account), and `tailscale up` is an interactive,
# account-specific step. Run `sudo tailscale up` manually after install.

set -e

if command -v tailscale >/dev/null 2>&1; then
    echo "tailscale: already installed ($(tailscale version 2>/dev/null | head -1))"
else
    case "$(uname -s)" in
        Linux)
            echo "tailscale: installing via official script"
            curl -fsSL https://tailscale.com/install.sh | sh
            ;;
        *)
            echo "tailscale: $(uname -s) host, skipping (install manually)" >&2
            exit 0
            ;;
    esac
fi

# Enable the daemon so tailscale survives reboots. Safe to re-run.
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now tailscaled
fi

if ! tailscale status >/dev/null 2>&1; then
    echo "tailscale: not logged in. Run \`sudo tailscale up\` to join your tailnet."
fi

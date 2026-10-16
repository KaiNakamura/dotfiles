#!/bin/sh
# Installs tailscale, starts tailscaled on boxes without systemd
# (PROFILE_START_TAILSCALE=true), and adds tailnet accounts from env keys.
# Keys: TS_AUTHKEY_PERSONAL, TS_AUTHKEY_WORK (never commit them).
# See docs/tailscale.md for switching.
set -e

DOTFILES_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/profile.sh
. "$DOTFILES_ROOT/lib/profile.sh"
# shellcheck source=../lib/shell_rc.sh
. "$DOTFILES_ROOT/lib/shell_rc.sh"

if command -v tailscale >/dev/null 2>&1; then
    echo "tailscale: already installed ($(tailscale version 2>/dev/null | head -1))"
elif [ "$(uname -s)" = Linux ]; then
    echo "tailscale: installing via official script"
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "tailscale: $(uname -s) host, skipping (install manually)" >&2
    exit 0
fi

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    sudo systemctl enable --now tailscaled
fi
ensure_tailscaled

# One profile per tailnet, nicknamed so `tailscale switch <name>` works.
for _n in personal work; do
    eval "_key=\${TS_AUTHKEY_$(echo "$_n" | tr a-z A-Z):-}"
    [ -n "$_key" ] || continue
    if sudo tailscale switch --list 2>/dev/null | grep -qw "$_n"; then
        echo "tailscale: $_n already added"
        continue
    fi
    echo "tailscale: adding $_n tailnet"
    sudo tailscale login --authkey="$_key" --nickname="$_n" \
        --hostname="${TS_HOSTNAME:-$(hostname)}"
done
unset _key

# Let this user run status/switch without sudo. Per profile, so set after login.
sudo tailscale set --operator="${USER:-$(id -un)}" >/dev/null 2>&1 || true

tailscale status >/dev/null 2>&1 ||
    echo "tailscale: not connected. See docs/tailscale.md"

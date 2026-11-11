#!/bin/sh
# Hermes spoke: default agent only, api_server on :8642 for the hub.
# Hub key: HERMES_HUB_KEY (never commit). See docs/hermes.md.
set -e

DOTFILES_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
WORKDIR="$DOTFILES_ROOT/hermes"
# shellcheck source=../lib/profile.sh
. "$DOTFILES_ROOT/lib/profile.sh"
# shellcheck source=../lib/asset.sh
. "$DOTFILES_ROOT/lib/asset.sh"
# shellcheck source=../lib/shell_rc.sh
. "$DOTFILES_ROOT/lib/shell_rc.sh"

HH=${HERMES_HOME:-$HOME/.hermes}
export PATH="$HOME/.local/bin:$PATH"

case $(uname -s) in
    Linux|Darwin) ;;
    *) echo "hermes-spoke: $(uname -s) host, skipping (install manually)" >&2; exit 0 ;;
esac

# kai-g727 had a trial install; set it aside once.
if [ "$(hostname -s)" = kai-g727 ] && [ -d "$HH" ] && [ ! -f "$HH/.spoke" ] \
    && [ ! -e "$HOME/.hermes.trial-bak" ]; then
    echo "hermes-spoke: backing up trial $HH -> ~/.hermes.trial-bak"
    mv "$HH" "$HOME/.hermes.trial-bak"
fi

# The trial's hermes lives under ~/.hermes, so check it runs, not just exists.
if hermes --version >/dev/null 2>&1; then
    echo "hermes-spoke: hermes already installed"
else
    # Non-interactive skips setup (and the Grok importer).
    echo "hermes-spoke: installing hermes via official script"
    # Spokes need no browser or computer-use.
    # Public PyPI: work boxes point uv/pip at CodeArtifact (401 when creds expire).
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh |
        env -u UV_INDEX_URL -u UV_EXTRA_INDEX_URL -u UV_INDEX -u PIP_INDEX_URL -u PIP_EXTRA_INDEX_URL \
            UV_DEFAULT_INDEX=https://pypi.org/simple UV_NO_CONFIG=1 PIP_CONFIG_FILE=/dev/null \
            bash -s -- --non-interactive --skip-computer-use --skip-browser
fi

mkdir -p "$HH"
touch "$HH/.spoke" "$HH/.env"
chmod 600 "$HH/.env"

# setenv KEY VALUE: replace or append in ~/.hermes/.env, quietly.
setenv() {
    _tmp=$(mktemp)
    grep -v "^$1=" "$HH/.env" > "$_tmp" || true
    printf '%s=%s\n' "$1" "$2" >> "$_tmp"
    cat "$_tmp" > "$HH/.env"
    rm -f "$_tmp"
}

setenv API_SERVER_ENABLED true
setenv API_SERVER_HOST 0.0.0.0
setenv API_SERVER_PORT 8642
if ! grep -q '^API_SERVER_KEY=.' "$HH/.env"; then
    setenv API_SERVER_KEY "$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')"
    echo "hermes-spoke: generated API_SERVER_KEY (hermes-spoke key)"
fi

hermes config set timezone America/New_York >/dev/null
printf 'Machine spoke %s. Do work on this machine when the hub (Grok Bot) asks. No routines or memory of other bots.\n' \
    "$(hostname -s)" > "$HH/SOUL.md"

cp "$(resolve_asset "$WORKDIR/hub.env")" "$HH/hub.env"
mkdir -p "$HOME/.local/bin"
# Hub SSH key, so the hub can install/maintain this spoke. Idempotent.
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys" && chmod 600 "$HOME/.ssh/authorized_keys"
grep -qF "$(cat "$WORKDIR/hub_ssh.pub")" "$HOME/.ssh/authorized_keys" ||
    cat "$WORKDIR/hub_ssh.pub" >> "$HOME/.ssh/authorized_keys"

cp "$WORKDIR/bin/hermes-spoke" "$HOME/.local/bin/hermes-spoke"
chmod +x "$HOME/.local/bin/hermes-spoke"

if [ -n "${HERMES_HUB_KEY:-}" ]; then
    hermes-spoke peer-hub
else
    echo "hermes-spoke: HERMES_HUB_KEY unset; peer later with:"
    echo "  HERMES_HUB_KEY=... hermes-spoke peer-hub"
fi

# Gateway: systemd user unit, else start_hermes (Coder), else manual.
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] \
    && systemctl --user daemon-reload 2>/dev/null; then
    mkdir -p "$HOME/.config/systemd/user"
    # Trial unit from `hermes gateway install` holds the same lock.
    systemctl --user disable --now hermes-gateway.service 2>/dev/null || true
    cp "$WORKDIR/systemd/hermes-spoke.service" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload
    systemctl --user enable hermes-spoke.service
    # Restart picks up new .env and SOUL.md.
    systemctl --user restart hermes-spoke.service
    # Keep running after logout.
    loginctl enable-linger "${USER:-$(id -un)}" 2>/dev/null || true
else
    case ${PROFILE_START_HERMES:-false} in
        true|yes|1) ensure_hermes_gateway ;;
        *) echo "hermes-spoke: no systemd; run 'hermes gateway install' or 'hermes gateway run'" ;;
    esac
fi

echo "hermes-spoke: register on hub with: hermes-spoke hub-cmd"

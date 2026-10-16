# Shell helpers for agent/headless boxes (POSIX).
# wire_shell_rc — idempotent rc block when PROFILE_WIRE_SHELL_RC=true
# ensure_dockerd — start dockerd when PROFILE_START_DOCKER=true (no systemd)
# ensure_tailscaled — start tailscaled when PROFILE_START_TAILSCALE=true (no systemd)
# shellcheck shell=sh

ensure_dockerd() {
    case ${PROFILE_START_DOCKER:-false} in
        true|yes|1) ;;
        *) return 0 ;;
    esac

    # Debian puts dockerd in /usr/sbin; non-root PATH often omits sbin.
    _dockerd=
    for _c in dockerd /usr/sbin/dockerd /usr/bin/dockerd; do
        if command -v "$_c" >/dev/null 2>&1; then
            _dockerd=$(command -v "$_c")
            break
        elif [ -x "$_c" ]; then
            _dockerd=$_c
            break
        fi
    done
    if [ -z "$_dockerd" ]; then
        echo "dockerd: not installed yet; skip"
        return 0
    fi

    if docker info >/dev/null 2>&1 || sudo docker info >/dev/null 2>&1; then
        echo "dockerd: already running"
        return 0
    fi

    echo "dockerd: starting (no systemd / policy-rc.d)"
    sudo mkdir -p /var/run "$HOME/.local/share"
    # Background; log for debugging
    sudo "$_dockerd" --host=unix:///var/run/docker.sock \
        >>"$HOME/.local/share/dockerd.log" 2>&1 &

    _i=0
    while [ "$_i" -lt 30 ]; do
        if sudo docker info >/dev/null 2>&1; then
            echo "dockerd: ready"
            return 0
        fi
        sleep 1
        _i=$((_i + 1))
    done
    echo "dockerd: started but socket not ready yet" >&2
    return 0
}

ensure_tailscaled() {
    case ${PROFILE_START_TAILSCALE:-false} in
        true|yes|1) ;;
        *) return 0 ;;
    esac
    [ -x /usr/sbin/tailscaled ] || { echo "tailscaled: not installed yet; skip"; return 0; }
    if [ -S /var/run/tailscale/tailscaled.sock ]; then
        echo "tailscaled: already running"
        return 0
    fi

    echo "tailscaled: starting (no systemd)"
    sudo mkdir -p /var/lib/tailscale /var/run/tailscale "$HOME/.local/share"
    # Kernel tun when /dev/net/tun exists, else userspace networking.
    _tun=
    [ -c /dev/net/tun ] || _tun=--tun=userspace-networking
    # nftables mode: the iptables-nft shim lacks connmark (health warning).
    # shellcheck disable=SC2086
    sudo env TS_DEBUG_FIREWALL_MODE=nftables /usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state \
        --socket=/var/run/tailscale/tailscaled.sock $_tun \
        >>"$HOME/.local/share/tailscaled.log" 2>&1 &

    _i=0
    while [ "$_i" -lt 15 ]; do
        if [ -S /var/run/tailscale/tailscaled.sock ]; then
            sudo tailscale set --operator="${USER:-$(id -un)}" >/dev/null 2>&1 || true
            echo "tailscaled: ready"
            return 0
        fi
        sleep 1
        _i=$((_i + 1))
    done
    echo "tailscaled: started but socket not ready yet" >&2
    return 0
}

wire_shell_rc() {
    _shell=${1:-bash}
    case ${PROFILE_WIRE_SHELL_RC:-false} in
        true|yes|1) ;;
        *) return 0 ;;
    esac

    case $_shell in
        bash) _rc=$HOME/.bashrc ;;
        zsh)  _rc=$HOME/.zshrc ;;
        *) echo "wire_shell_rc: unsupported shell $_shell" >&2; return 1 ;;
    esac

    _marker="# >>> dotfiles >>>"
    _end="# <<< dotfiles <<<"
    touch "$_rc"
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share"

    if grep -q "$_marker" "$_rc" 2>/dev/null; then
        _tmp=$(mktemp)
        awk -v m="$_marker" -v e="$_end" '
            $0 == m {skip=1; next}
            $0 == e {skip=0; next}
            !skip {print}
        ' "$_rc" > "$_tmp"
        mv "$_tmp" "$_rc"
    fi

    {
        echo ""
        echo "$_marker"
        echo "# Managed by dotfiles lib/shell_rc.sh. Do not edit by hand."
        echo "export DOTFILES_ROOT=\"$DOTFILES_ROOT\""
        # Cargo/rustup before brew so ~/.cargo/bin beats /usr/bin/rustc.
        echo '[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"'
        echo 'export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"'
        echo '[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"'
        echo 'export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"'
        echo '[ -f "$DOTFILES_ROOT/bash/aliases.bash" ] && . "$DOTFILES_ROOT/bash/aliases.bash"'
        echo 'for f in "$DOTFILES_ROOT"/bash/functions/*.bash; do [ -f "$f" ] && . "$f"; done'
        echo 'command -v starship >/dev/null && eval "$(starship init '"$_shell"')"'
        echo 'command -v zoxide >/dev/null && eval "$(zoxide init '"$_shell"')"'
        echo 'command -v th >/dev/null && eval "$(th shell '"$_shell"' 2>/dev/null)"'
        echo '[ -f "$HOME/.fzf.'"$_shell"'" ] && . "$HOME/.fzf.'"$_shell"'"'
        # Idempotent dockerd/tailscaled start when profile sets start_docker (sourced helper).
        echo 'if [ -f "$DOTFILES_ROOT/lib/shell_rc.sh" ]; then'
        echo '  # shellcheck source=/dev/null'
        echo '  . "$DOTFILES_ROOT/lib/profile.sh"'
        echo '  . "$DOTFILES_ROOT/lib/shell_rc.sh"'
        echo '  ensure_dockerd >/dev/null'
        echo '  ensure_tailscaled >/dev/null'
        echo 'fi'
        echo "$_end"
    } >> "$_rc"

    echo "shell_rc: wired $_shell block into $_rc"
}

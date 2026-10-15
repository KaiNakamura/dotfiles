#!/bin/sh
# Ensures docker engine + docker group. Optionally starts dockerd when
# PROFILE_START_DOCKER=true (boxes without systemd / with policy-rc.d).
set -e

DOTFILES_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/profile.sh
. "$DOTFILES_ROOT/lib/profile.sh"
# shellcheck source=../lib/shell_rc.sh
. "$DOTFILES_ROOT/lib/shell_rc.sh"

if command -v docker >/dev/null 2>&1; then
    echo "docker: already installed ($(docker --version 2>/dev/null | head -1))"
elif [ -S /var/run/docker.sock ]; then
    echo "docker: socket present but no client; skipping (DooD pattern?)"
else
    case "$(uname -s)" in
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                echo "docker: installing docker.io via apt"
                sudo apt-get update -y
                sudo apt-get install -y docker.io
            else
                echo "docker: non-apt Linux distro, skipping (install manually)" >&2
                exit 0
            fi
            ;;
        *)
            echo "docker: $(uname -s) host, skipping (use Docker Desktop)" >&2
            exit 0
            ;;
    esac
fi

if getent group docker >/dev/null 2>&1; then
    if ! id -nG "${USER:-$(id -un)}" | tr ' ' '\n' | grep -qx docker; then
        echo "docker: adding ${USER:-$(id -un)} to docker group (active after next login)"
        sudo usermod -aG docker "${USER:-$(id -un)}"
    fi
fi

ensure_dockerd

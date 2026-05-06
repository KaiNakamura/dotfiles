#!/bin/bash
# docker module: ensures docker engine + docker group on the host.
#
# Coder template preinstalls docker -> this is a no-op there.
# Home/work fresh install: apt-get install docker.io + usermod.
#
# Group activation in the same shell is NOT attempted. Modules that need
# docker during install must use `sudo docker` (see obsidian/install.sh).
# Interactive `docker` works after the user's next login.
#
# Why no `sg`/`newgrp`/re-exec: official Docker docs only recommend
# `newgrp docker` (interactive) or relogin. No upstream tool surveyed
# (get.docker.com, devcontainers, Ansible community.docker) bridges the
# activation gap inside a single script. `sudo docker` is the de-facto
# pattern: socket is root:docker 0660, sudo bypasses the group entirely.

set -e

if command -v docker >/dev/null 2>&1; then
    echo "docker: already installed ($(docker --version 2>/dev/null | head -1))"
elif [[ -S /var/run/docker.sock ]]; then
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
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
        echo "docker: adding $USER to docker group (active after next login)"
        sudo usermod -aG docker "$USER"
    fi
fi

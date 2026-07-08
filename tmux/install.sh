#!/bin/bash
# tmux module: installs tmux via apt-get

set -e

if command -v tmux >/dev/null 2>&1; then
    echo "tmux: already installed ($(tmux -V 2>/dev/null))"
else
    case "$(uname -s)" in
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                echo "tmux: installing via apt-get"
                sudo apt-get update -y
                sudo apt-get install -y tmux
            else
                echo "tmux: non-apt Linux distro, skipping (install manually)" >&2
                exit 0
            fi
            ;;
        *)
            echo "tmux: $(uname -s) host, skipping (install manually)" >&2
            exit 0
            ;;
    esac
fi
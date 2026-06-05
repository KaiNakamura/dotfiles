#!/bin/bash
# coder module: installs the coder binary (https://coder.com).
#
# The same binary serves as both client and server. This module only installs
# it for client use (`coder login <url>`, `coder ssh`, etc.). On Debian/Ubuntu
# the official script installs a deb package that also ships a `coder.service`
# systemd unit; it is left disabled here. The coder-server module enables and
# configures it on the machine that acts as the control plane.

set -e

if command -v coder >/dev/null 2>&1; then
    echo "coder: already installed ($(coder version 2>/dev/null | head -1))"
    exit 0
fi

case "$(uname -s)" in
    Linux)
        echo "coder: installing via official script"
        curl -fsSL https://coder.com/install.sh | sh
        ;;
    *)
        echo "coder: $(uname -s) host, skipping (install manually)" >&2
        exit 0
        ;;
esac

#!/bin/bash
# go module: installs the Go toolchain.
#
# Needed before the kde module, which builds dotool from source (`go build`).
# Must run earlier than kde in INSTALL_ORDER.

set -e

if command -v go >/dev/null 2>&1; then
    echo "go: already installed ($(go version 2>/dev/null))"
    exit 0
fi

if command -v brew >/dev/null 2>&1; then
    echo "go: installing via brew"
    brew install go
else
    echo "go: brew not found, install Go manually: https://go.dev/dl/" >&2
    exit 1
fi

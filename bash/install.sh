#!/bin/sh
# Coder: roadgnar shim sources bash/ in-place (wire_shell_rc=false).
# Agent boxes with wire_shell_rc=true get an idempotent ~/.bashrc block.
set -e
DOTFILES_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/profile.sh
. "$DOTFILES_ROOT/lib/profile.sh"
# shellcheck source=../lib/shell_rc.sh
. "$DOTFILES_ROOT/lib/shell_rc.sh"
wire_shell_rc bash

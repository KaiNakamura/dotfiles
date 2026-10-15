#!/bin/bash
# Coder: files are sourced in-place from ~/repos/dotfiles/bash/ by the
# roadgnar/dotfiles@KaiNakamura shell/init.bash. Install stays a no-op.
#
# Grok: no external shim, so append a small sourced block to ~/.bashrc.

source "$(dirname "$0")/../lib/profile.sh"

if [[ "$DOTFILES_PROFILE" != "grok" ]]; then
    :
    exit 0
fi

MARKER="# >>> grok-dotfiles >>>"
END_MARKER="# <<< grok-dotfiles <<<"
DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASHRC="$HOME/.bashrc"

# Idempotent: replace prior block if present
if grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    # strip old block
    tmp="$(mktemp)"
    awk -v m="$MARKER" -v e="$END_MARKER" '
        $0 == m {skip=1; next}
        $0 == e {skip=0; next}
        !skip {print}
    ' "$BASHRC" > "$tmp"
    mv "$tmp" "$BASHRC"
fi

mkdir -p "$HOME/.local/bin"
{
    echo ""
    echo "$MARKER"
    echo "# Managed by dotfiles bash/install.sh --profile grok. Do not edit by hand."
    echo "export DOTFILES_ROOT=\"$DOTFILES_ROOT\""
    echo '[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"'
    echo '[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"'
    echo 'export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"'
    echo '[ -f "$DOTFILES_ROOT/bash/aliases.bash" ] && . "$DOTFILES_ROOT/bash/aliases.bash"'
    echo 'for f in "$DOTFILES_ROOT"/bash/functions/*.bash; do [ -f "$f" ] && . "$f"; done'
    echo 'command -v starship >/dev/null && eval "$(starship init bash)"'
    echo 'command -v zoxide >/dev/null && eval "$(zoxide init bash)"'
    echo 'command -v th >/dev/null && eval "$(th shell bash 2>/dev/null)"'
    echo '[ -f "$HOME/.fzf.bash" ] && . "$HOME/.fzf.bash"'
    echo "$END_MARKER"
} >> "$BASHRC"

echo "bash: wired grok block into ~/.bashrc"

# wire_shell_rc <bash|zsh> — idempotent rc block when PROFILE_WIRE_SHELL_RC=true
# shellcheck shell=sh

wire_shell_rc() {
    _shell=${1:-bash}
    case $PROFILE_WIRE_SHELL_RC in
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

    if grep -q "$_marker" "$_rc" 2>/dev/null; then
        _tmp=$(mktemp)
        awk -v m="$_marker" -v e="$_end" '
            $0 == m {skip=1; next}
            $0 == e {skip=0; next}
            !skip {print}
        ' "$_rc" > "$_tmp"
        mv "$_tmp" "$_rc"
    fi

    mkdir -p "$HOME/.local/bin"
    {
        echo ""
        echo "$_marker"
        echo "# Managed by dotfiles lib/shell_rc.sh. Do not edit by hand."
        echo "export DOTFILES_ROOT=\"$DOTFILES_ROOT\""
        echo '[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"'
        echo '[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"'
        echo 'export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"'
        echo '[ -f "$DOTFILES_ROOT/bash/aliases.bash" ] && . "$DOTFILES_ROOT/bash/aliases.bash"'
        echo 'for f in "$DOTFILES_ROOT"/bash/functions/*.bash; do [ -f "$f" ] && . "$f"; done'
        echo 'command -v starship >/dev/null && eval "$(starship init '"$_shell"')"'
        echo 'command -v zoxide >/dev/null && eval "$(zoxide init '"$_shell"')"'
        echo 'command -v th >/dev/null && eval "$(th shell '"$_shell"' 2>/dev/null)"'
        echo '[ -f "$HOME/.fzf.'"$_shell"'" ] && . "$HOME/.fzf.'"$_shell"'"'
        echo "$_end"
    } >> "$_rc"

    echo "shell_rc: wired $_shell block into $_rc"
}

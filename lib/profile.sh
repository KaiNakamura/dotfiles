# Profile loader (POSIX). Source after setting DOTFILES_ROOT.
# Exports: DOTFILES_PROFILE PROFILE_CHAIN PROFILE_MODULES
#          PROFILE_GIT_MODE PROFILE_WIRE_SHELL_RC PROFILE_SHELL

# shellcheck shell=sh

_profile_trim() {
    # trim leading/trailing whitespace
    printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

_profile_get() {
    # _profile_get <file> <key> -> value (empty if missing)
    _f=$1
    _k=$2
    [ -f "$_f" ] || return 0
    # strip comments, match key =
    _line=$(grep -E "^[[:space:]]*${_k}[[:space:]]*=" "$_f" | tail -n 1) || true
    [ -n "$_line" ] || return 0
    _profile_trim "${_line#*=}"
}

_profile_list_remove() {
    # stdin words, args = words to remove
    _out=
    while read -r _w; do
        [ -z "$_w" ] && continue
        _keep=1
        for _r in "$@"; do
            [ "$_w" = "$_r" ] && _keep=0 && break
        done
        [ "$_keep" -eq 1 ] && _out="$_out $_w"
    done
    _profile_trim "$_out"
}

load_profile() {
    # optional arg overrides ~/.dotfiles-profile
    if [ -n "${1:-}" ]; then
        DOTFILES_PROFILE=$1
    else
        DOTFILES_PROFILE=$(cat "$HOME/.dotfiles-profile" 2>/dev/null || echo home)
    fi
    export DOTFILES_PROFILE

    if [ -z "${DOTFILES_ROOT:-}" ]; then
        echo "profile.sh: DOTFILES_ROOT is not set" >&2
        return 1
    fi

    _conf="$DOTFILES_ROOT/profiles/${DOTFILES_PROFILE}.conf"
    if [ ! -f "$_conf" ]; then
        echo "profile.sh: missing $_conf" >&2
        return 1
    fi

    # Build extend chain (root first, leaf last), detect cycles
    _chain=
    _cur=$DOTFILES_PROFILE
    _guard=0
    while [ -n "$_cur" ] && [ "$_guard" -lt 16 ]; do
        _chain="$_cur $_chain"
        _parent=$(_profile_get "$DOTFILES_ROOT/profiles/${_cur}.conf" extends)
        [ -z "$_parent" ] && break
        case " $_chain " in
            *" $_parent "*) echo "profile.sh: cycle at $_parent" >&2; return 1 ;;
        esac
        _cur=$_parent
        _guard=$((_guard + 1))
    done
    # _chain is root ... leaf; PROFILE_CHAIN for assets is leaf ... root
    PROFILE_CHAIN=
    for _p in $_chain; do
        PROFILE_CHAIN="$_p $PROFILE_CHAIN"
    done
    PROFILE_CHAIN=$(_profile_trim "$PROFILE_CHAIN")
    export PROFILE_CHAIN

    # Merge flags/modules root → leaf (child overrides)
    PROFILE_MODULES=
    PROFILE_GIT_MODE=replace
    PROFILE_WIRE_SHELL_RC=false
    PROFILE_SHELL=zsh
    _add=
    _remove=

    for _p in $_chain; do
        _cf="$DOTFILES_ROOT/profiles/${_p}.conf"
        _m=$(_profile_get "$_cf" modules)
        [ -n "$_m" ] && PROFILE_MODULES=$_m
        _a=$(_profile_get "$_cf" modules_add)
        [ -n "$_a" ] && _add="$_add $_a"
        _r=$(_profile_get "$_cf" modules_remove)
        [ -n "$_r" ] && _remove="$_remove $_r"
        _g=$(_profile_get "$_cf" git_mode)
        [ -n "$_g" ] && PROFILE_GIT_MODE=$_g
        _w=$(_profile_get "$_cf" wire_shell_rc)
        [ -n "$_w" ] && PROFILE_WIRE_SHELL_RC=$_w
        _s=$(_profile_get "$_cf" shell)
        [ -n "$_s" ] && PROFILE_SHELL=$_s
    done

    PROFILE_MODULES=$(_profile_trim "$PROFILE_MODULES $_add")
    if [ -n "$(_profile_trim "$_remove")" ]; then
        PROFILE_MODULES=$(printf '%s\n' $PROFILE_MODULES | _profile_list_remove $_remove)
    fi

    export PROFILE_MODULES PROFILE_GIT_MODE PROFILE_WIRE_SHELL_RC PROFILE_SHELL
}

# Auto-load when sourced if DOTFILES_ROOT is set
if [ -n "${DOTFILES_ROOT:-}" ]; then
    load_profile
fi

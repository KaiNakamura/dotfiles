# resolve_asset <path> — walk PROFILE_CHAIN then bare file.
# Tries name.<profile>.ext, name.ext.<profile>, then bare.
# Requires: DOTFILES_PROFILE chain via lib/profile.sh
# shellcheck shell=sh

resolve_asset() {
    _path=$1
    _dir=$(dirname "$_path")
    _base=$(basename "$_path")

    # extension: last .component if base has a dot after first char
    _name=$_base
    _ext=
    case $_base in
        .*.*) # e.g. .zshrc.work handled as whole for pattern B
            ;;
        *.*)
            _ext=.${_base##*.}
            _name=${_base%.*}
            ;;
    esac

    for _p in $PROFILE_CHAIN; do
        for _cand in \
            "$_dir/${_name}.${_p}${_ext}" \
            "$_dir/${_base}.${_p}"
        do
            if [ -f "$_cand" ]; then
                printf '%s\n' "$_cand"
                return 0
            fi
        done
    done

    if [ -f "$_path" ]; then
        printf '%s\n' "$_path"
        return 0
    fi

    echo "resolve_asset: not found: $_path (chain: $PROFILE_CHAIN)" >&2
    return 1
}

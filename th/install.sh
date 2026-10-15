#!/bin/sh
# The `th` thoughts vault CLI, plus optional KDE helpers.
set -e

WORKDIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
TARGET_BIN="$HOME/.local/bin"
TH_REPO="https://github.com/KaiNakamura/th"

if ! command -v cargo >/dev/null 2>&1; then
    echo "  Installing: rust (prerequisite for th)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Prefer rustup's toolchain over any older system rustc (e.g. Debian's).
# shellcheck disable=SC1091
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
export PATH="$HOME/.cargo/bin:$PATH"

# Fetch git deps with the git CLI so gh HTTPS credentials apply (private repos).
mkdir -p "$HOME/.cargo"
if [ -f "$HOME/.cargo/config.toml" ]; then
    if ! grep -q 'git-fetch-with-cli' "$HOME/.cargo/config.toml" 2>/dev/null; then
        printf '\n[net]\ngit-fetch-with-cli = true\n' >> "$HOME/.cargo/config.toml"
    fi
else
    printf '[net]\ngit-fetch-with-cli = true\n' > "$HOME/.cargo/config.toml"
fi
# Point git at gh's credential helper when available (no tokens in the script).
if command -v gh >/dev/null 2>&1; then
    gh auth setup-git >/dev/null 2>&1 || true
fi
export CARGO_NET_GIT_FETCH_WITH_CLI=true

echo "  Installing: th"
if ! cargo install --git "$TH_REPO"; then
    echo "  cargo --git failed; cloning via gh and installing from path"
    TH_SRC="${TH_SRC:-$HOME/repos/th}"
    mkdir -p "$(dirname "$TH_SRC")"
    if [ ! -d "$TH_SRC/.git" ]; then
        gh repo clone KaiNakamura/th "$TH_SRC"
    else
        git -C "$TH_SRC" pull --ff-only || true
    fi
    cargo install --path "$TH_SRC"
fi

# KWin helpers only on KDE.
case ${XDG_CURRENT_DESKTOP:-} in
    *KDE*) ;;
    *)
        echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
        echo "Skipping th desktop helpers (KDE not detected)"
        exit 0
        ;;
esac

mkdir -p "$TARGET_BIN"
for script in "$WORKDIR"/bin/*; do
    [ -f "$script" ] || continue
    name=$(basename "$script")
    echo "  Installing: $name"
    cp "$script" "$TARGET_BIN/$name"
    chmod +x "$TARGET_BIN/$name"
done

echo "Done."

#!/bin/bash
# Orchestrator: loads profiles/*.conf then runs each module's install.sh.
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT="$WORKDIR"

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

SUDO_PID=""
keep_sudo_alive() {
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
    done
}
cleanup() {
    if [[ -n "$SUDO_PID" ]]; then
        kill "$SUDO_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

pre_install() {
    print_info "Preparing installation environment..."
    if [[ -z "$BASH_VERSION" ]]; then
        print_error "This script must be run with bash"
        exit 1
    fi
    if sudo -n true 2>/dev/null; then
        print_info "Sudo credentials already available"
    else
        print_info "Requesting sudo access..."
        sudo -v
    fi
    keep_sudo_alive &
    SUDO_PID=$!
    mkdir -p ~/.config ~/.local/bin ~/.local/share/fonts
    export PATH="$PATH:$HOME/.local/bin"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    configure_homebrew
    print_success "Environment prepared"
}

# Homebrew 7+ asks before every install; the prefix brew.env applies to all brew calls.
configure_homebrew() {
    command -v brew >/dev/null || return 0
    local env_file
    env_file="$(brew --prefix)/etc/homebrew/brew.env"
    mkdir -p "$(dirname "$env_file")"
    grep -qx "HOMEBREW_NO_ASK=1" "$env_file" 2>/dev/null || echo "HOMEBREW_NO_ASK=1" >> "$env_file"
}

install_module() {
    local module="$1"
    local module_dir="$WORKDIR/$module"
    if [[ ! -d "$module_dir" ]]; then
        print_error "Module '$module' does not exist"
        return 1
    fi
    if [[ ! -f "$module_dir/install.sh" ]]; then
        print_error "Module '$module' does not have an install.sh script"
        return 1
    fi
    print_info "Installing $module..."
    chmod +x "$module_dir/install.sh"
    (cd "$module_dir" && bash ./install.sh)
    if [[ $? -eq 0 ]]; then
        print_success "Successfully installed $module"
        return 0
    else
        print_error "Failed to install $module"
        return 1
    fi
}

main() {
    local profile=""
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                profile="$2"
                shift 2
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    set -- "${args[@]}"

    if [[ -n "$profile" ]]; then
        echo "$profile" > ~/.dotfiles-profile
        print_info "Set dotfiles profile to: $profile"
    fi

    # shellcheck source=lib/profile.sh
    . "$WORKDIR/lib/profile.sh"
    load_profile

    pre_install

    local modules
    if [[ $# -gt 0 ]]; then
        modules=("$@")
        print_info "Installing specified modules: ${modules[*]}"
    else
        # PROFILE_MODULES is space-separated from profiles/*.conf
        # shellcheck disable=SC2206
        modules=($PROFILE_MODULES)
        print_info "Profile $DOTFILES_PROFILE modules: ${modules[*]}"
    fi

    local failed_modules=()
    local successful_modules=()

    for module in "${modules[@]}"; do
        if [[ ! -d "$WORKDIR/$module" ]]; then
            print_error "Module '$module' does not exist"
            exit 1
        fi
        if [[ ! -f "$WORKDIR/$module/install.sh" ]]; then
            print_error "Module '$module' is missing install.sh"
            exit 1
        fi
    done

    for module in "${modules[@]}"; do
        echo ""
        if install_module "$module"; then
            successful_modules+=("$module")
        else
            failed_modules+=("$module")
            print_error "Stopping installation due to failure"
            break
        fi
    done

    echo ""
    echo "================== INSTALLATION SUMMARY =================="
    if [[ ${#successful_modules[@]} -gt 0 ]]; then
        print_success "Successfully installed: ${successful_modules[*]}"
    fi
    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        print_error "Failed to install: ${failed_modules[*]}"
        exit 1
    fi
    print_success "All modules installed successfully!"
    print_info "You may need to restart your computer for some changes to take effect."
}

main "$@"

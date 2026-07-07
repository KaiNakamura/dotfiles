#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Explicit installation order based on dependencies
INSTALL_ORDER=(
    "wayland"
    "git-config"
    "nerd-font"
    "zsh"
    "starship"
    "zoxide"
    "kitty"
    "nvim"
    "vim"
    "go"
    "kde"
    "cursor-ai"
    "claude"
    "bat"
    "btop"
    "delta"
    "eza"
    "fd"
    "fzf"
    "worktrunk"
    "tldr"
    "aws"
    "earlyoom"
    "tailscale"
    "coder"
)

# Subset for headless Coder workspaces (no GUI, bash login shell).
# `brew` runs first because most tool modules below install via Homebrew, which
# is absent on the base image; the brew module bootstraps it and the parent
# sources its shellenv (see install loop) so later modules can use `brew`.
INSTALL_ORDER_CODER=(
    "brew"
    "git-config"
    "bash"
    "starship"
    "claude"
    "vim"
    "zoxide"
    "bat"
    "btop"
    "delta"
    "eza"
    "fd"
    "fzf"
    "tldr"
    "aws"
    "worktrunk"
    "nvim"
    "docker"
    # TODO: obsidian is omitted here. Its module builds/runs an obsidianless
    # Docker container for the headless Obsidian CLI, but a Coder workspace is
    # itself a container with no Docker daemon (Docker-in-Docker fails). Add it
    # back once the obsidian module gains a native backend (install the Obsidian
    # AppImage + Xvfb directly, no nested Docker) selected when no daemon is
    # reachable. Until then, vault-health/Obsidian CLI is unavailable in coder
    # workspaces (Claude can still read/write vault files directly).
)

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Sudo keep-alive function
SUDO_PID=""
keep_sudo_alive() {
    # Keep sudo alive in background
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
    done
}

# Cleanup function
cleanup() {
    if [[ -n "$SUDO_PID" ]]; then
        kill "$SUDO_PID" 2>/dev/null || true
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Pre-install hook: Setup environment
pre_install() {
    print_info "Preparing installation environment..."
    
    # Ensure we're running in bash
    if [[ -z "$BASH_VERSION" ]]; then
        print_error "This script must be run with bash"
        exit 1
    fi
    
    # Refresh sudo timestamp (keep it alive for the duration)
    if sudo -n true 2>/dev/null; then
        print_info "Sudo credentials already available"
    else
        print_info "Requesting sudo access..."
        sudo -v
    fi
    
    # Start sudo keep-alive in background
    keep_sudo_alive &
    SUDO_PID=$!
    
    # Create necessary directories
    mkdir -p ~/.config
    mkdir -p ~/.local/bin
    mkdir -p ~/.local/share/fonts
    
    # Export paths for other install steps
    export PATH="$PATH:$HOME/.local/bin"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    
    print_success "Environment prepared"
}

# Function to install a single module
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
    
    # Make the install script executable
    chmod +x "$module_dir/install.sh"
    
    # Force bash execution, even if script has different shebang
    (cd "$module_dir" && bash ./install.sh)
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Successfully installed $module"
        return 0
    else
        print_error "Failed to install $module"
        return 1
    fi
}

# Main script logic
main() {
    # Parse --profile flag
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

    # Write profile if specified
    if [[ -n "$profile" ]]; then
        echo "$profile" > ~/.dotfiles-profile
        print_info "Set dotfiles profile to: $profile"
    fi

    pre_install

    # Determine which modules to install
    if [[ $# -gt 0 ]]; then
        # Use provided modules as arguments
        modules=("$@")
        print_info "Installing specified modules in provided order: ${modules[*]}"
    elif [[ "$profile" == "coder" ]]; then
        modules=("${INSTALL_ORDER_CODER[@]}")
        print_info "Installing Coder subset: ${modules[*]}"
    else
        # Use default installation order
        modules=("${INSTALL_ORDER[@]}")
        print_info "Installing all modules in predefined order..."
    fi
    
    failed_modules=()
    successful_modules=()
    
    # Validate all modules exist before starting installation
    for module in "${modules[@]}"; do
        if [[ ! -d "$WORKDIR/$module" ]]; then
            print_error "Module '$module' does not exist"
            exit 1
        fi
        
        if [[ ! -f "$WORKDIR/$module/install.sh" ]]; then
            print_error "Module '$module' is missing install.sh script"
            exit 1
        fi
    done
    
    # Install modules in order, stop on first failure
    for module in "${modules[@]}"; do
        echo ""
        if install_module "$module"; then
            successful_modules+=("$module")
            # The brew module installs Homebrew in a subshell; pull its shellenv
            # into this process so subsequent brew-based modules find `brew`.
            if [[ "$module" == "brew" ]] && [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
                eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            fi
        else
            failed_modules+=("$module")
            print_error "Stopping installation due to failure"
            break
        fi
    done
    
    # Summary
    echo ""
    echo "================== INSTALLATION SUMMARY =================="
    
    if [[ ${#successful_modules[@]} -gt 0 ]]; then
        print_success "Successfully installed: ${successful_modules[*]}"
    fi
    
    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        print_error "Failed to install: ${failed_modules[*]}"
        exit 1
    else
        print_success "All modules installed successfully!"
    fi
    
    print_info "You may need to restart your computer for some changes to take effect."
}

# Run main function with all arguments
main "$@"

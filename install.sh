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
    "git-config"
    "nerd-font"
    "zsh"
    "starship"
    "zoxide"
    "kitty"
    "nvim"
    "vim"
    "kde"
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

# Post-install hook: Finalize installation
post_install() {
    print_info "Finalizing installation..."
    
    # Handle zsh switching (provide instructions, don't execute)
    if command -v zsh &> /dev/null; then
        ZSH_PATH=$(which zsh)
        print_info "To make zsh your default shell, run:"
        print_info "  sudo chsh -s $ZSH_PATH $USER"
        print_info "Then log out and log back in, or run: exec zsh"
    fi
    
    print_success "Installation finalized"
}

# Main script logic
main() {
    pre_install
    
    print_info "Installing all modules in predefined order..."
    
    modules=("${INSTALL_ORDER[@]}")
    failed_modules=()
    successful_modules=()
    
    # Validate all modules exist before starting installation
    for module in "${modules[@]}"; do
        if [[ ! -d "$WORKDIR/$module" ]]; then
            print_warning "Module '$module' not found, skipping..."
            continue
        fi
        
        if [[ ! -f "$WORKDIR/$module/install.sh" ]]; then
            print_error "Module '$module' is missing install.sh script"
            exit 1
        fi
    done
    
    # Install modules in order, stop on first failure
    for module in "${modules[@]}"; do
        # Skip if module doesn't exist
        if [[ ! -d "$WORKDIR/$module" ]]; then
            continue
        fi
        
        echo ""
        if install_module "$module"; then
            successful_modules+=("$module")
        else
            failed_modules+=("$module")
            print_error "Stopping installation due to failure"
            break
        fi
    done
    
    post_install
    
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

# Run main function
main

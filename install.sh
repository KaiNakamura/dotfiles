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
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Function to get all available modules
get_modules() {
  find "$DOTFILES_DIR" -maxdepth 1 -type d -name "*" | while read -r dir; do
    module_name=$(basename "$dir")
    # Skip hidden directories, current directory, and directories without install.sh
    if [[ "$module_name" != .* ]] && [[ "$module_name" != "$(basename "$DOTFILES_DIR")" ]] && [[ -f "$dir/install.sh" ]]; then
      echo "$module_name"
    fi
  done | sort
}

# Function to install a single module
install_module() {
    local module="$1"
    local module_dir="$DOTFILES_DIR/$module"
    
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
    
    # Change to the module directory and run the install script
    (cd "$module_dir" && ./install.sh)
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully installed $module"
        return 0
    else
        print_error "Failed to install $module"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [modules...] | --all | --list | --help"
    echo ""
    echo "Examples:"
    echo "  $0 git vim              # Install git and vim modules"
    echo "  $0 --all                # Install all available modules"
    echo "  $0 --list               # List all available modules"
    echo "  $0 --help               # Show this help message"
    echo ""
    echo "Available modules:"
    get_modules | sed 's/^/  /'
}

# Main script logic
main() {
    # Check if no arguments provided
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    # Handle special flags
    case "$1" in
        --help|-h)
            show_usage
            exit 0
            ;;
        --list|-l)
            echo "Available modules:"
            get_modules | sed 's/^/  /'
            exit 0
            ;;
        --all|-a)
            sudo -v
            print_info "Installing all modules..."
            modules=($(get_modules))
            if [[ ${#modules[@]} -eq 0 ]]; then
                print_warning "No modules found"
                exit 0
            fi
            ;;
        *)
            modules=("$@")
            ;;
    esac

    # Ensure sudo is available
    sudo -v
    
    # Validate all modules exist before starting installation
    for module in "${modules[@]}"; do
        if [[ ! -d "$DOTFILES_DIR/$module" ]]; then
            print_error "Module '$module' does not exist"
            echo ""
            echo "Available modules:"
            get_modules | sed 's/^/  /'
            exit 1
        fi
    done
    
    # Install modules
    failed_modules=()
    successful_modules=()
    
    for module in "${modules[@]}"; do
        echo ""
        if install_module "$module"; then
            successful_modules+=("$module")
        else
            failed_modules+=("$module")
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
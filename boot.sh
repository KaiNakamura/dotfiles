#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    print_error "This script is designed for Linux (Kubuntu 24.04 LTS)"
    exit 1
fi

print_info "Starting dotfiles bootstrap installation..."

# Request sudo access and start keep-alive
print_info "Requesting sudo access..."
sudo -v

# Start sudo keep-alive in background
keep_sudo_alive &
SUDO_PID=$!

# Install essential packages
sudo apt update && sudo apt install -y \
    git \
    curl \
    wget \
    tmux

# NOTE: We want to authenticate with GitHub ASAP since that's got a lot of
# manual steps that require user interaction

# Install Homebrew if not already installed
if command -v brew &> /dev/null; then
    print_info "Homebrew is already installed, skipping..."
else
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for current session
    if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -f ~/.linuxbrew/bin/brew ]]; then
        eval "$(~/.linuxbrew/bin/brew shellenv)"
    fi
    
    # Add Homebrew to shell config (bashrc)
    if ! grep -q "brew shellenv" ~/.bashrc 2>/dev/null; then
        echo >> ~/.bashrc
        if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
        elif [[ -f ~/.linuxbrew/bin/brew ]]; then
            echo 'eval "$(~/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
        fi
    fi
fi

# Ensure Homebrew is in PATH
if command -v brew &> /dev/null; then
    print_success "Homebrew is ready"
else
    print_error "Failed to set up Homebrew. Please run: eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
    exit 1
fi

# Install GitHub CLI if not already installed
if command -v gh &> /dev/null; then
    print_info "GitHub CLI is already installed, skipping..."
else
    print_info "Installing GitHub CLI..."
    brew install gh
fi

# Authenticate with GitHub
if gh auth status &> /dev/null; then
    print_info "GitHub is already authenticated, skipping..."
else
    print_info "Authenticating with GitHub..."
    print_warning "You will need to authenticate GitHub. Follow the prompts..."
    gh auth login -p ssh -w
fi

# Ensure .ssh directory exists
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Determine SSH key path
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_KEY_PUB="$HOME/.ssh/id_ed25519.pub"

# Generate SSH key if none exists
if [[ ! -f "$SSH_KEY" ]]; then
    print_info "No SSH key found. Generating SSH key..."
    ssh-keygen -t ed25519 -C "kaihnakamura@gmail.com" -f "$SSH_KEY" -N ""
else
    print_info "SSH key found at $SSH_KEY"
fi

# Ensure SSH agent is running and key is loaded
eval "$(ssh-agent -s)" 2>/dev/null || true
ssh-add "$SSH_KEY" 2>/dev/null || true

# Check if key is uploaded to GitHub and working
KEY_UPLOADED=false
if gh auth status &> /dev/null; then
    # Test SSH connectivity to GitHub
    print_info "Testing SSH connectivity to GitHub..."
    if ssh -T git@github.com -o StrictHostKeyChecking=no -o ConnectTimeout=5 &> /dev/null; then
        KEY_UPLOADED=true
        print_success "SSH key is configured and working"
    else
        # SSH test failed, upload the key
        print_info "SSH key not working with GitHub. Uploading key..."
        KEY_TITLE="kai@$(hostname) ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
        gh ssh-key add "$SSH_KEY_PUB" --title "$KEY_TITLE"
        
        # Wait a moment for GitHub to process
        sleep 2
        
        # Verify it works now
        if ssh -T git@github.com -o StrictHostKeyChecking=no -o ConnectTimeout=5 &> /dev/null; then
            KEY_UPLOADED=true
            print_success "SSH key uploaded and verified"
        else
            print_warning "SSH key uploaded but verification failed. May need a moment to propagate."
            KEY_UPLOADED=true  # Assume it will work, GitHub sometimes takes a moment
        fi
    fi
else
    print_warning "GitHub not authenticated. Cannot verify SSH key upload."
    print_warning "SSH key exists locally but may not be uploaded to GitHub."
fi

# Install additional dependencies
sudo apt update && sudo apt install -y \
    cmake \
    build-essential
brew install gcc

# Clone dotfiles repository
DOTFILES_DIR="$HOME/repos/dotfiles"
if [[ -d "$DOTFILES_DIR" ]]; then
    print_info "Dotfiles repository already exists, updating..."
    cd "$DOTFILES_DIR"
    git pull origin main || git pull origin master
else
    print_info "Cloning dotfiles repository..."
    mkdir -p ~/repos
    cd ~/repos
    git clone git@github.com:KaiNakamura/dotfiles.git
    cd dotfiles
fi

# Run the install script
print_info "Running dotfiles installer..."
chmod +x install.sh
./install.sh


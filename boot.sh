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
    # Enable accessible prompter to avoid escape sequence issues with survey library
    export GH_ACCESSIBLE_PROMPTER=1
    export TERM="${TERM:-xterm-256color}"
    # gh checks os.Stdin and os.Stdout for TTY detection
    gh auth login -p ssh < /dev/tty > /dev/tty
fi

# Setup SSH key for GitHub
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
SSH_PUB_KEY_PATH="$SSH_KEY_PATH.pub"

# Generate SSH key if it doesn't exist
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    print_info "Generating SSH key..."
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -C "" -N "" -f "$SSH_KEY_PATH"
    print_success "SSH key generated"
fi

# Add SSH key to agent
print_info "Adding SSH key to agent..."
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_KEY_PATH" 2>/dev/null || true

# Upload SSH key to GitHub
# gh ssh-key add will fail if scope is missing, but we handle that gracefully
print_info "Uploading SSH key to GitHub..."
KEY_TITLE="${USER}@$(hostname) ($(date -u +%Y-%m-%dT%H:%M:%SZ))"

# Try to upload - if it fails due to scope, we'll handle it
UPLOAD_OUTPUT=$(gh ssh-key add "$SSH_PUB_KEY_PATH" --title "$KEY_TITLE" 2>&1)
UPLOAD_EXIT=$?

if [[ $UPLOAD_EXIT -eq 0 ]]; then
    if echo "$UPLOAD_OUTPUT" | grep -q "already exists"; then
        print_info "SSH key already exists on GitHub"
    elif echo "$UPLOAD_OUTPUT" | grep -q "added to your account"; then
        print_success "SSH key uploaded to GitHub"
    else
        print_success "SSH key processed"
    fi
else
    # Check if it's a scope error
    if echo "$UPLOAD_OUTPUT" | grep -qi "admin:public_key\|404\|403\|scope\|permission"; then
        print_warning "Missing admin:public_key scope. Refreshing authentication..."
        if gh auth refresh -h github.com -s admin:public_key < /dev/tty > /dev/tty 2>&1; then
            # Retry upload after refresh
            print_info "Retrying SSH key upload..."
            RETRY_OUTPUT=$(gh ssh-key add "$SSH_PUB_KEY_PATH" --title "$KEY_TITLE" 2>&1)
            if [[ $? -eq 0 ]]; then
                if echo "$RETRY_OUTPUT" | grep -q "added to your account\|already exists"; then
                    print_success "SSH key uploaded to GitHub"
                else
                    print_success "SSH key processed"
                fi
            else
                print_error "Failed to upload SSH key after refresh"
                print_error "Output: $RETRY_OUTPUT"
                exit 1
            fi
        else
            print_error "Failed to refresh authentication. Please run manually:"
            print_error "  gh auth refresh -h github.com -s admin:public_key"
            exit 1
        fi
    else
        print_error "Failed to upload SSH key:"
        echo "$UPLOAD_OUTPUT" >&2
        exit 1
    fi
fi

# Verify SSH connectivity with retries (no sleep - just retry)
print_info "Verifying SSH connectivity to GitHub..."
MAX_RETRIES=5
RETRY_COUNT=0
SSH_WORKING=false

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if ssh -T git@github.com -o StrictHostKeyChecking=no -o ConnectTimeout=5 &> /dev/null; then
        SSH_WORKING=true
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
        print_info "SSH not ready yet, retrying ($RETRY_COUNT/$MAX_RETRIES)..."
    fi
done

if [[ "$SSH_WORKING" == "true" ]]; then
    print_success "SSH authentication is working"
else
    print_error "SSH authentication to GitHub failed after $MAX_RETRIES attempts."
    print_error "The key may need a moment to propagate. You can verify manually with:"
    print_error "  ssh -T git@github.com"
    exit 1
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
    gh repo clone KaiNakamura/dotfiles
    cd dotfiles
fi

# Run the install script
print_info "Running dotfiles installer..."
chmod +x install.sh
./install.sh


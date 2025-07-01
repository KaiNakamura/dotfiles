#!/bin/bash

# Dotfiles Installation Script
# This script copies important configuration files to your home directory

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Dotfiles Installation Script${NC}"
echo -e "${BLUE}=============================${NC}"
echo ""

# Function to backup existing files
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}Backing up existing $file to $backup${NC}"
        cp "$file" "$backup"
    fi
}

# Function to copy a dotfile
copy_dotfile() {
    local source="$1"
    local dest="$2"
    local file_desc="$3"
    
    if [[ -f "$source" ]]; then
        echo -e "${BLUE}Installing $file_desc...${NC}"
        backup_file "$dest"
        cp "$source" "$dest"
        echo -e "${GREEN}✓ Copied $source to $dest${NC}"
    else
        echo -e "${RED}✗ Warning: $source not found${NC}"
    fi
}

# List of dotfiles to copy
# Format: "source_file:destination_file:description"
dotfiles=(
    ".gitconfig:$HOME/.gitconfig:Git configuration"
    ".vimrc:$HOME/.vimrc:Vim configuration"
    ".gitignore:$HOME/.gitignore:Global gitignore"
	".config/kitty/kitty.conf:$HOME/.config/kitty/kitty.conf:Kitty config"
)

echo -e "${BLUE}Starting dotfiles installation...${NC}"
echo ""

# Copy each dotfile
for dotfile in "${dotfiles[@]}"; do
    IFS=':' read -r source dest desc <<< "$dotfile"
    source="$SCRIPT_DIR/$source"
    copy_dotfile "$source" "$dest" "$desc"
    echo ""
done

echo -e "${GREEN}Dotfiles installation complete!${NC}"
echo ""
echo -e "${YELLOW}Note: If you had existing dotfiles, they have been backed up with timestamps.${NC}"
echo -e "${YELLOW}You can find them in your home directory with .backup.YYYYMMDD_HHMMSS extensions.${NC}"
echo ""

echo -e "${GREEN}All done! Your dotfiles have been installed.${NC}"

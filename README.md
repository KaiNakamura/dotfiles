# Dotfiles

My personal config for quick and easy setup

## Installation

```bash
# Install some dependencies
sudo apt install -y \
    git \
    curl \
    wget \
    tmux \
    cmake \
    build-essential

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to path
echo >> /home/kai/.bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/kai/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Install gcc
brew install gcc

# Install GitHub CLI
brew install gh

# Authenticate GitHub
gh auth login -p ssh -w

# Set up repos
mkdir -p ~/repos && cd ~/repos

# Clone dotfiles
git clone git@github.com:KaiNakamura/dotfiles.git && cd dotfiles

# Run the installer
./install.sh
```

## TODO

- [ ] Figure out a way to upload quickly to the dotfiles (e.g., If I edit my .vimrc locally, I want a way to quickly update my ~/repos/dotfiles/.vimrc)

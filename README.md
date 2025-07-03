# Dotfiles

My personal config for quick and easy setup

## Installation

WARNING: Installation will overwrite existing configuration files, make backups if needed before proceeding

For a quick install

```bash
git clone git@github.com:KaiNakamura/dotfiles.git && cd dotfiles
./install.sh --all
```

Or if installing from a completely fresh OS

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
echo >> ~/.bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Homebrew recommends installing gcc
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
./install.sh --all
```

Some other settings you may want to configure:

- System Settings -> Mouse -> Pointer Speed = -0.4 (Depends on mouse though)
- Wallpaper & Splash Screen
- Display Configuration

## TODO

- [ ] Neovim
- [ ] Zsh
- [ ] Figure out a way to upload quickly to the dotfiles (e.g., If I edit my .vimrc locally, I want a way to quickly update my ~/repos/dotfiles/.vimrc)
- [ ] Figure out a way to handle dependencies and installing certain modules before others
- [ ] Figure out some way to do "profiles" (e.g., Install certain software for "personal" and others for "work")

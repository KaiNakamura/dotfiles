# Dotfiles

My personal config for quick and easy setup

## Installation

For a fresh [Kubuntu 24.04 LTS](https://cdimage.ubuntu.com/kubuntu/releases/noble/release/) installation:

```bash
# Install essential packages
sudo apt update && sudo apt install -y \
    git \
    curl \
    wget \
    tmux \
    cmake \
    build-essential

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc

# Install GitHub CLI (and gcc since brew recommends it)
brew install gh gcc

# Authenticate with GitHub (follow prompts, choose to generate/upload SSH key when asked)
gh auth login -p ssh

# Clone and install dotfiles
mkdir -p ~/repos
cd ~/repos
gh repo clone KaiNakamura/dotfiles
cd dotfiles
./install.sh
```

If you already have the repository cloned:

```bash
cd ~/repos/dotfiles
./install.sh
```

Some other settings you may want to configure:

- System Settings -> Mouse -> Pointer Speed = -0.4 (Depends on mouse though)
- Wallpaper & Splash Screen
- Display Configuration

## TODO

- [ ] Make sure the wayland session stuff works on a fresh install
- [ ] Add a module for work stuff?
- [ ] Keybinds for kitty and firefox not working properly ootb
- [ ] Also firefox gets messed up on install?
- [ ] Maybe different profile pic? Or accent color in KDE?
- [ ] Git config for default branch and also rebase false
- [ ] Window Managment -> Task Switcher -> Filter windows by Screens (Current screen)
- [ ] Fix Cursor/VS Code leader keys not working for panel selection when no file open
- [ ] Consider changing Meta+Shift+# (move window to desktop) to also change to that desktop
- [ ] Consider Meta+Ctrl+# to move all windows to that desktop number
- [ ] Consider Meta+Ctrl+Shift+# to "switch" desktop windows
- [ ] Some kind of visual indicator when a window gets focused?
- [ ] Hotkeys for switching between apps? (Like Alt+Shift+# instead of Alt+Tab?)
- [ ] Would be nice if Meta+HJKL didn't switch focus if we're already on that screen
- [ ] Some kind of auto-tiling? Similar to TWM behavior (is this even possible in KDE?)
- [ ] AWS CLI

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

## Profiles

Different machines can have different configurations (e.g., work vs home). Set a profile before or during install:

```bash
# Set profile during install
./install.sh --profile work

# Or set it manually (install.sh reads this file)
echo "work" > ~/.dotfiles-profile
```

Available profiles: `home` (default), `work`

### What profiles affect

- **Default browser**: `home` = Firefox, `work` = Chrome (in `kde/settings.sh` and `kde/open-browser/open-browser.sh`)
- **Starship prompt**: Uses `starship.work.toml` if it exists and profile is `work`

### Machine-specific shell config

For shell customizations that shouldn't be in the repo (work aliases, proxy settings, etc.), create `~/.zshrc.local`. It's sourced at the end of `.zshrc` and is not tracked by git.

Some other settings you may want to configure:

- System Settings -> Mouse -> Pointer Speed = -0.4 (Depends on mouse though)
- Wallpaper & Splash Screen
- Display Configuration

## TODO

- [ ] Move mouse to windows when changing focus
- [ ] More keybinds
    - [ ] Consider changing Meta+Shift+# (move window to desktop) to also change to that desktop
    - [ ] Consider Meta+Ctrl+# to move all windows to that desktop number
    - [ ] Consider Meta+Ctrl+Shift+# to "switch" desktop windows (i.e., swap the current with the other one)
    - [ ] Hotkeys for switching between apps? (Like Alt+Shift+# instead of Alt+Tab?)
- [ ] Some kind of visual indicator when a window gets focused?
    - [ ] Have some basic visual indicator now, but maybe something that looks better?
- [ ] Wayland/X11 related stuff
    - [ ] Make sure the wayland session stuff works on a fresh install
    - [ ] Keybinds for kitty and firefox not working properly ootb
    - [ ] Also firefox gets messed up on install? (this seems to be related to X11 vs. Wayland, reproducible which swapping between them)
- [ ] Maybe different profile pic? Or accent color in KDE?
- [ ] Fix Cursor/VS Code leader keys not working for panel selection when no file open (Update: actually this does seem to work, I think it just seems to not sometimes because it takes time for vim keybinds to load, any way to speed that up?)
    - [ ] A bit lower priority, kind of moving back to nvim anyways
- [ ] Some kind of auto-tiling? Similar to TWM behavior (is this even possible in KDE?)

### Notes for Agentic Workflow

Kind of separate from TODO but also under the same umbrella. Planning out improvements for agentic workflows and sticking points I'm noticing while working with Cursor commands (will maybe help things when looking at OpenCode later).

- I want some way of being more permissive for what agents are allowed to touch. Oftentimes I'll have to approve requests for touching `.thoughts` files, but they should always be allowed to touch these.
- Some way to avoid colliding environments (containerized seems like the way to go, but there's also large overhead in that, Git worktrees might be another option but things could get messy if they're making their own `.thoughts` directory instead of a shared one). Maybe everything on my local machine? But might make being permissive for what it can/can't do a bit harder...

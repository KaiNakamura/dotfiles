# Dotfiles

My personal config for quick and easy setup

## Installation

First, some core utilities:

```bash
sudo apt install -y \
    git \
    curl \
    wget \
    tmux \
    cmake \
    vim-gtk3
```

Then clone and install:

```bash
git clone git@github.com:KaiNakamura/dotfiles.git ~/repos/dotfiles && cd ~/repos/dotfiles && bash install.sh
```

Or if already cloned, just the install:

```bash
bash install.sh
```

Existing dotfiles are backed up with timestamps (e.g., `<file>.backup.YYYYMMDD_HHMMSS`)

# Dotfiles

My personal config for quick and easy setup

## Installation

### Quick Install

For a fresh [Kubuntu 24.04 LTS](https://cdimage.ubuntu.com/kubuntu/releases/noble/release/) installation, run:

```bash
wget -qO- https://raw.githubusercontent.com/KaiNakamura/dotfiles/main/boot.sh | bash
```

### Manual Install

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

- [ ] Neovim
- [ ] Zsh
- [ ] Use symlink for vimrc as well
- [ ] Fix starship prompt symbol (and finalize colors)
- [ ] Maybe have some kind of "install" vs. "sync config" mode?
- [ ] Figure out a way to upload quickly to the dotfiles (e.g., If I edit my .vimrc locally, I want a way to quickly update my ~/repos/dotfiles/.vimrc)
- [ ] Figure out a way to handle dependencies and installing certain modules before others
- [ ] Figure out some way to do "profiles" (e.g., Install certain software for "personal" and others for "work")

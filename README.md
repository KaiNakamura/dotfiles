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

Available profiles: `home` (default), `work`, `coder`

### What profiles affect

- **Default browser**: `home` = Firefox, `work` = Chrome (in `kde/settings.sh` and `kde/open-browser/open-browser.sh`)
- **Starship prompt**: `starship/install.sh` copies `starship.<profile>.toml` to `~/.config/starship.toml` when it exists, else falls back to `starship.toml`.

### Machine-specific shell config

For shell customizations that shouldn't be in the repo (work aliases, proxy settings, etc.), create `~/.zshrc.local`. It's sourced at the end of `.zshrc` and is not tracked by git.

Some other settings you may want to configure:

- System Settings -> Mouse -> Pointer Speed = -0.4 (Depends on mouse though)
- Wallpaper & Splash Screen
- Display Configuration

## First-time Coder workspace setup

For Coder workspaces that ship with a service-account token wired into `gh` for
the work org. To clone personal `KaiNakamura/*` repos, authenticate personal
GitHub account once:

```sh
gh auth login -p ssh
```

A `gh()` wrapper (loaded only when `CODER=true`) routes `gh auth *` and any
`gh` call referencing `KaiNakamura/*` through a personal config dir; everything
else falls through to the default. No-op on local machines.

Then you can clone repos as needed within Coder instances:

```sh
gwc KaiNakamura/thoughts ~/repos/thoughts
```

## Local Coder server

The `coder-server` module turns a machine into a self-hosted
[Coder](https://coder.com) control plane (workspaces run as Docker containers
on that host, reachable over the personal tailnet). It belongs to no profile
and must be installed explicitly on the server machine:

```bash
# Prerequisites: tailscale installed and logged in
./install.sh tailscale
sudo tailscale up

# Stand up the server (pulls in docker, coder, and ollama modules
# automatically; also pulls the local coding model)
./install.sh coder-server
```

It also brings up a local model server: the `ollama` module installs the
ollama runtime bound to the tailnet IP (with a 64K context window, needed for
Claude Code's large prompts), and `coder-server` pulls the coding model
(default `glm-4.7-flash`, a 30B-A3B MoE that drives Claude Code's agentic
tool-calling well; it CPU-offloads on a 12GB card but only 3B params are active)
and records the endpoint + default model in `/etc/coder.d/coder.env`
(`LOCAL_CODER_OLLAMA_URL`, `LOCAL_CODER_MODEL`).

The `ollama` module can also be installed on its own (runtime only, no model):

```bash
./install.sh ollama
```

### Local-coder workspace template

`coder-template/` is a Coder workspace template (Terraform) for a plain CPU
Docker workspace that runs Claude Code against the local ollama model over the
tailnet. It clones `KaiNakamura/dotfiles` and runs `./install.sh --profile
coder` on start, and pre-sets Claude Code's Anthropic-compatible API env vars
to point at ollama. Push it to the server, and set `ollama_url` to the desktop's
tailnet endpoint (the `ollama_url` template variable becomes `ANTHROPIC_BASE_URL`
inside the workspace; it must be the host's tailnet IP, not `localhost` or
`host.docker.internal`, because ollama binds to the tailnet IP only):

```sh
coder login http://<server-tailnet-ip>:3000
coder templates push local-coder -d ./coder-template \
    --variable ollama_url=http://$(tailscale ip -4 | head -1):11434
```

Other machines get the `coder` client module from the normal install and
connect with:

```sh
coder login http://<server-tailnet-ip>:3000
```

## TODO

- [ ] Install broken because Go required for dotool!

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

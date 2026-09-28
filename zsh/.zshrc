export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Neovim
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
export PATH="/home/kai/.pixi/bin:$PATH"
alias v="vim"
alias nv="nvim"
alias nvz="nvim ~/.zshrc"
alias nvzl="nvim ~/.zshrc.local"

# Starship
eval "$(starship init zsh)"

# Explorer
e() {
  local target="${1:-.}"
  command xdg-open "$target" </dev/null >/dev/null 2>&1 &!
}

# Git Aliases
alias g="git"
alias gs="git status"
alias ga="git add"
alias gm="git commit -m"
alias gam="git add . && git commit -m"
alias gb="git branch"
alias gp="git push"
alias gpo="git push origin"
alias gpu="git pull origin"
alias gc="git checkout"
alias gl="git log"
alias gw="git worktree"
# Redundant with oh-my-zsh git plugin (which also defines these),
# kept here for parity with bash aliases and so they work without omz.
alias gf="git fetch"
alias gd="git diff"

# Clone a repo as bare + .bare pattern for worktree workflow
# Usage: gwc owner/repo [directory]
gwc() {
  local repo=$1
  local name=${2:-$(basename "$repo" .git)}
  mkdir "$name" && cd "$name"
  gh repo clone "$repo" .bare -- --bare
  echo "gitdir: ./.bare" > .git
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git fetch origin
}

# Worktrunk (git worktree manager)
eval "$(wt config shell init zsh)"
alias wts="wt switch"
alias wtl="wt list"
alias wtc="wt switch --create"
alias wtr="wt remove"

# Thoughts vault CLI. The eval defines the `th` shell function that wraps the
# binary, and is not optional: a process cannot cd its parent shell, so `th
# vault` and `th project` hand the destination back through it. Guarded because
# th is installed from source rather than by a package manager, so unlike wt
# above it may genuinely be absent.
command -v th > /dev/null 2>&1 && eval "$(th shell zsh)"
alias ths="th status"
alias thsa="th status --all"
alias thp="th project"
alias thr="th repo"
alias tha="th agents"
alias thv="th vault"
alias tho="th open"
alias thd="th doctor"
alias thda="th doctor --all"
alias thb="board open"

# k8s
alias k="kubectl"
alias kx="kubectx"

# For Cursor (and probably other apps) to not be slow on wayland
export ELECTRON_OZONE_PLATFORM_HINT=auto

# zoxide
alias cd="z"
eval "$(zoxide init zsh)"
export _ZO_DOCTOR=0

# bat
# Remove decorations and disable pager, this is useful for things that
# expect `cat` to behave like `cat`.
alias cat="bat --style plain --pager never"

# eza
# Default options: --group-directories-first --icons
alias ls="eza --group-directories-first --icons"
alias la="eza -a --group-directories-first --icons"
alias ll="eza -al --group-directories-first --icons"
alias lt="eza -a --tree --level=1 --group-directories-first --icons"

# fzf
# Setup fzf key bindings and fuzzy completion
# This is typically done by $(brew --prefix)/opt/fzf/install, but we source it here
# to ensure it's available in the shell
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Machine-specific overrides (may be managed by install.sh --profile)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

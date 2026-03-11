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

# Starship
eval "$(starship init zsh)"

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

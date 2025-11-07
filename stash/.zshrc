# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
eval "$(pyenv virtualenv-init -)"

# pipx
export PIP_REQUIRE_VIRTUALENV=true

# Created by `pipx` on 2025-07-03 15:07:41
export PATH="$PATH:/home/kai/.local/bin"

# TFSwitch
export PATH=$PATH:$HOME/.bin
export PATH=$PATH:$HOME/bin

# uv
export UV_PYTHON_PREFERENCE=only-managed

# roadgnar/build
# Set if you want to include aliases
export CYVL_INCLUDE_ALIASES=1


# Set to the directory where you clone repositories
export CYVL_REPO_PARENT_DIR=~/repos

eval "$(/home/kai/dev/cyvl/build/init shell)"

export STARSHIP_CONFIG=/home/kai/dev/cyvl/build/starship.toml

# direnv
eval "$(direnv hook zsh)"

# k8s
source $(brew --prefix)/opt/kube-ps1/share/kube-ps1.sh
export PS1="\$(kube_ps1)\n$PS1"

# pnpm
export PNPM_HOME="/home/kai/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# TODO: Added this manually since yarn being dumb for import
export PATH="/home/kai/.local/share/pnpm/nodejs/22.16.0/bin:$PATH"
# pnpm end

# Neovim
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
export PATH="/home/kai/.pixi/bin:$PATH"
alias v="vim"
alias nv="nvim"

# Task
eval "$(task --completion zsh)"

# Initialize starship for zsh
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

# k8s
alias k="kubectl"
alias kx="kubectx"

# CloudCompare
alias cc="flatpak run org.cloudcompare.CloudCompare"

# Tailscale
alias ts="tailscale"

# For Cursor (and probably other apps) to not be slow as hell on wayland
export ELECTRON_OZONE_PLATFORM_HINT=auto

# Go
export PATH="$PATH:$HOME/go/bin"

# zoxide
alias cd="z"
eval "$(zoxide init zsh)"

# Surpress zoxide warnings, they seem to appear when Cursor runs commands, unsure why
export _ZO_DOCTOR=0

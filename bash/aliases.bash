# Personal aliases for KaiNakamura branch.
# Sourced from shell/init.bash. Bash translations of Kai's zsh aliases.
# Requires complete_alias library (loaded by init.bash) for git/wt/eza completions.

# Editor
alias v='vim'
alias nv='nvim'

# Git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gm='git commit -m'
alias gam='git add . && git commit -m'
alias gb='git branch'
alias gp='git push'
alias gpo='git push origin'
alias gpu='git pull origin'
alias gc='git checkout'
alias gl='git log'
alias gw='git worktree'
alias gf='git fetch'
alias gd='git diff'

# Worktrunk
alias wts='wt switch'
alias wtl='wt list'
alias wtc='wt switch --create'
alias wtr='wt remove'

# Thoughts vault CLI
alias ths='th status'
alias thsa='th status --all'
alias thp='th project'
alias thr='th repo'
alias tha='th agents'
alias thv='th vault'
alias tho='th open'
alias thd='th doctor'
alias thda='th doctor --all'

# zoxide
alias cd='z'

# bat
alias cat='bat --style plain --pager never'

# eza
alias ls='eza --group-directories-first --icons'
alias la='eza -a --group-directories-first --icons'
alias ll='eza -al --group-directories-first --icons'
alias lt='eza -a --tree --level=1 --group-directories-first --icons'

# k9s: open across all namespaces by default. k9s has no global config knob
# for default namespace (issue derailed/k9s#2665, closed not-planned); the
# per-cluster state file is seeded with namespace.active=default on first
# connect. Aliasing to `-A` covers every cluster the moment it's first
# accessed and is the maintainer-recommended workaround.
alias k9s='k9s -A'

# Wire alias completion (only in interactive shells where complete_alias is loaded)
if declare -F _complete_alias >/dev/null 2>&1; then
  for _a in g gs ga gm gam gb gp gpo gpu gc gl gw gf gd wts wtl wtc wtr ths thsa thp thr thv tho thd thda la ll lt; do
    complete -F _complete_alias "$_a"
  done
  unset _a
fi

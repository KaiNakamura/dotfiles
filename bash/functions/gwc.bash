# gwc -- clone a repo as bare + .bare layout for worktree workflow.
# Uses `gh` so private repos work with the workspace's GitHub auth.
#
# Usage: gwc <org/repo|full-url> [dir]
gwc() {
  local repo="$1"
  if [[ -z "$repo" ]]; then
    echo "Usage: gwc <org/repo|full-url> [dir]" >&2
    return 1
  fi
  local name="${2:-$(basename "$repo" .git)}"
  if [[ -e "$name" ]]; then
    echo "Already exists: $name" >&2
    return 1
  fi
  mkdir "$name" && cd "$name" || return 1
  gh repo clone "$repo" .bare -- --bare || return 1
  echo "gitdir: ./.bare" > .git
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git fetch origin
}

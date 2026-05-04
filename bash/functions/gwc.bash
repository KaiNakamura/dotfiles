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

  # On Coder workspaces, cyvl-dev's global gitconfig rewrites
  # git@github.com: -> https://github.com/ -> http://git-proxy...:8080/, and
  # our personal include adds an identity rule on https://github.com/ to keep
  # plugin clones off the proxy. Net effect: a freshly gh-cloned bare repo's
  # origin stays HTTPS, and `git fetch origin` from an interactive shell
  # (where cyvl-dev unsets GIT_ASKPASS) has no credential helper and prompts.
  # Pin origin to SSH and add a longer-prefix local identity insteadOf so the
  # global SSH->HTTPS rewrite no longer applies to this exact remote. Coder's
  # GIT_SSH_COMMAND (gitssh wrapper) then handles auth.
  if [[ "${CODER:-}" == "true" ]]; then
    local origin_url
    origin_url=$(git config --get remote.origin.url)
    case "$origin_url" in
      https://github.com/*)
        local gh_path="${origin_url#https://github.com/}"
        gh_path="${gh_path%.git}"
        origin_url="git@github.com:${gh_path}.git"
        git remote set-url origin "$origin_url"
        ;;
    esac
    case "$origin_url" in
      git@github.com:*)
        git config --local --replace-all "url.${origin_url}.insteadOf" "$origin_url"
        grep -q "^github.com " ~/.ssh/known_hosts 2>/dev/null \
          || ssh-keyscan -t rsa,ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null
        ;;
    esac
  fi

  git fetch origin
}

# bare_clone_via_proxy -- pre-create a slop-ctl-shaped bare repo using the
# cyvvy git proxy so the fetch succeeds in any context (Coder dotfiles agent
# script, systemd --user, etc.).
#
# Why this exists: cyvl-user-setup.service runs slop-ctl under systemd, which
# has no GIT_SSH_COMMAND, no ssh-agent, no key, and no ~/.ssh/known_hosts.
# When the personal owner-scoped `insteadOf` rules in ~/.gitconfig-personal
# rewrite https://github.com/roadgnar/* to ssh://, the systemd-context fetch
# fails with "Host key verification failed" and slop-ctl leaves an empty bare
# behind. See coder-dotfiles iter-12 understanding-01 / plan-01.
#
# We side-step the rewrite chain by fetching from the proxy URL directly:
# none of our `insteadOf` sources match `http://git-proxy.internal.coder:8080/`,
# and the cyvvy-installed credential helper authenticates the proxy with its
# token. The bare repo's `remote.origin.url` is left as `https://github.com/...`
# (matching what slop-ctl would have written), so subsequent interactive
# operations (`gpu`, `git fetch`, etc.) re-enter the iter-08 round-6 SSH path
# normally.
#
# When slop-ctl runs later it sees `<repo>/.git` already exists, logs
# "already cloned, reusing" (slop_ctl/setup_exec.py:644), and proceeds to
# `wt switch ^` to materialize the default-branch worktree.
#
# Usage: bare_clone_via_proxy <owner> <name> [default_branch]
bare_clone_via_proxy() {
  local owner="$1"
  local name="$2"
  local default_branch="${3:-main}"
  local repo_dir="$HOME/repos/$name"
  local proxy_url="http://git-proxy.internal.coder:8080/$owner/$name"
  local origin_url="https://github.com/$owner/$name"

  if [ ! -d "$repo_dir/.git" ]; then
    echo "personal: bare-cloning $owner/$name via proxy..."
    mkdir -p "$repo_dir"
    git init --bare "$repo_dir/.git" >/dev/null
    git -C "$repo_dir" remote add origin "$origin_url"
    git -C "$repo_dir" config remote.origin.gh-resolved "$owner/$name"
    git -C "$repo_dir" config worktrunk.default-branch "$default_branch"
  fi

  # Heal an empty bare left by a prior cyvl-user-setup.service fetch failure:
  # `.git/` exists from `git init --bare` but `refs/remotes/origin/` is empty
  # (or missing) and there are no packed origin refs.
  local origin_refs="$repo_dir/.git/refs/remotes/origin"
  local needs_fetch=0
  if [ ! -d "$origin_refs" ] || [ -z "$(ls -A "$origin_refs" 2>/dev/null)" ]; then
    if ! grep -q "^[0-9a-f]\+ refs/remotes/origin/" "$repo_dir/.git/packed-refs" 2>/dev/null; then
      needs_fetch=1
    fi
  fi

  if [ "$needs_fetch" -eq 1 ]; then
    echo "personal: fetching $owner/$name refs via proxy..."
    git -C "$repo_dir" fetch "$proxy_url" "+refs/heads/*:refs/remotes/origin/*"
  fi
}

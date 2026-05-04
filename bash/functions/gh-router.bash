# gh routing: send KaiNakamura/* traffic and `gh auth *` through a personal
# gh config dir, with GH_TOKEN and GITHUB_TOKEN both cleared so gh uses the
# personal config's stored auth (not the workspace's work-account env tokens).
# Everything else falls through to the default workspace gh (work service
# account via GH_TOKEN/GITHUB_TOKEN).
#
# Active only inside a Coder workspace; on local machines this file no-ops.
#
# One-time per fresh workspace: `gh auth login -p ssh` (auto-routed personal).

[ "${CODER:-}" = "true" ] || return 0

gh() {
  if [ "${1:-}" = "auth" ]; then
    GH_CONFIG_DIR="$HOME/.config/gh-personal" GH_TOKEN= GITHUB_TOKEN= command gh "$@"
    return $?
  fi

  local arg prev=""
  local personal=0

  for arg in "$@"; do
    case "$prev" in
      -R|--repo)
        case "$arg" in
          KaiNakamura/*) personal=1; break ;;
        esac
        ;;
    esac
    case "$arg" in
      KaiNakamura/*) personal=1; break ;;
      https://github.com/KaiNakamura/*) personal=1; break ;;
      git@github.com:KaiNakamura/*) personal=1; break ;;
    esac
    prev="$arg"
  done

  if [ "$personal" -eq 0 ]; then
    local origin
    origin=$(git remote get-url origin 2>/dev/null) || origin=""
    case "$origin" in
      *KaiNakamura/*) personal=1 ;;
    esac
  fi

  if [ "$personal" -eq 1 ]; then
    GH_CONFIG_DIR="$HOME/.config/gh-personal" GH_TOKEN= GITHUB_TOKEN= command gh "$@"
  else
    command gh "$@"
  fi
}

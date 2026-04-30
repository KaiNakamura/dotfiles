# gh routing: send KaiNakamura/* traffic to a personal gh config dir, leave
# everything else on the default workspace gh (which uses GH_TOKEN with the
# roadgnar service-account JWT injected by the cyvl-dev template).
#
# One-time per fresh workspace: run `gh_personal_login` to do the device-flow
# auth + SSH key upload into ~/.config/gh-personal/.

gh() {
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
    GH_CONFIG_DIR="$HOME/.config/gh-personal" GH_TOKEN= command gh "$@"
  else
    command gh "$@"
  fi
}

gh_personal_login() {
  GH_CONFIG_DIR="$HOME/.config/gh-personal" GH_TOKEN= command gh auth login \
    --hostname github.com --git-protocol ssh
}

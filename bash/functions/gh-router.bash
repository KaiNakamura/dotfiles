# gh routing on Coder workspaces.
#
# Sourced TWICE from ~/.bashrc:
#   1) Top, via roadgnar init.bash. Defines gh() with personal-flow logic so
#      gh works pre-cyvl-dev-wrapper for any early-init scripts.
#   2) Bottom, via personal-tail block appended by install_personal.sh, AFTER
#      cyvl-dev's gh-proxy-wrapper. Snapshots cyvl-dev's gh() into
#      _gh_cyvl_inner and delegates non-personal calls so workspace
#      gh-resolved / GH_REPO routing still wraps work repos.
#
# Routing rules:
#   gh auth *                  -> personal config dir, env tokens cleared
#   KaiNakamura/* refs         -> personal config dir, env tokens cleared
#   bare repo subcmd name      -> rewritten to roadgnar/<name> (work default;
#                                 use explicit KaiNakamura/<name> for personal)
#   everything else            -> cyvl-dev gh-proxy-wrapper (or raw gh)
#
# No-ops outside Coder.

[ "${CODER:-}" = "true" ] || return 0

if declare -f gh >/dev/null 2>&1 \
   && ! declare -f _gh_cyvl_inner >/dev/null 2>&1 \
   && ! declare -f gh | grep -q "_GH_ROUTER_OURS=1"; then
  eval "$(declare -f gh | sed "1s/^gh /_gh_cyvl_inner /")"
fi

gh() {
  local _GH_ROUTER_OURS=1
  if [ "${1:-}" = "auth" ]; then
    GH_CONFIG_DIR="$HOME/.config/gh-personal" GH_TOKEN= GITHUB_TOKEN= command gh "$@"
    return $?
  fi

  local arg prev="" personal=0
  for arg in "$@"; do
    case "$prev" in
      -R|--repo) case "$arg" in KaiNakamura/*) personal=1; break ;; esac ;;
    esac
    case "$arg" in
      KaiNakamura/*|https://github.com/KaiNakamura/*|git@github.com:KaiNakamura/*)
        personal=1; break ;;
    esac
    prev="$arg"
  done

  if [ "$personal" -eq 0 ]; then
    local origin
    origin=$(git remote get-url origin 2>/dev/null) || origin=""
    case "$origin" in *KaiNakamura/*) personal=1 ;; esac
  fi

  # Default bare repo names to roadgnar/<name>. gh has no default-owner concept
  # and the workspace OAuth token resolves "viewer" as KaiNakamura, so a bare
  # "platform" would otherwise become KaiNakamura/platform and 404. Personal
  # repos still route via explicit "KaiNakamura/<name>" (matched above).
  local rc bare_name="" bare_op=0
  if [ "$personal" -eq 0 ] && [ "${1:-}" = "repo" ]; then
    case "${2:-}" in
      clone|view|fork|sync|create)
        case "${3:-}" in
          ""|-*|*/*|https://*|git@*|ssh://*) ;;
          *) bare_op=1; bare_name="$3"; set -- "$1" "$2" "roadgnar/$3" "${@:4}" ;;
        esac
        ;;
    esac
  fi

  if [ "$personal" -eq 1 ]; then
    GH_CONFIG_DIR="$HOME/.config/gh-personal" GH_TOKEN= GITHUB_TOKEN= command gh "$@"
    rc=$?
  elif declare -f _gh_cyvl_inner >/dev/null 2>&1; then
    _gh_cyvl_inner "$@"
    rc=$?
  else
    command gh "$@"
    rc=$?
  fi

  if [ "$rc" -ne 0 ] && [ "$bare_op" -eq 1 ] && [ "$personal" -eq 0 ]; then
    printf "\\033[33mhint:\\033[0m bare names default to roadgnar/. For a personal repo: gh repo %s KaiNakamura/%s\\n" "$2" "$bare_name" >&2
  fi

  return $rc
}

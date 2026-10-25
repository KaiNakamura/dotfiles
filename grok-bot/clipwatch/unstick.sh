#!/usr/bin/env bash
# Unfreeze Grok Bot after an X11 paste hang: put a responsive plain-text
# owner on CLIPBOARD so Electron's stuck SelectionRequester can finish.
set -euo pipefail
printf '%s' "${1:- }" | xclip -selection clipboard -i -t text/plain
echo "clipboard re-owned with plain text; try pasting again (or restart Grok Bot if still stuck)"

---
name: dictionary
description: Teach Voxtype dictation a word it keeps mishearing by opening a dotfiles PR. Use when the user says dictation got a word wrong, e.g. "that should have said Omarchy, fix it in my dotfiles".
---

The dictionary lives in the dotfiles repo at `voxtype/config.toml`. Change it only through a PR so the user reviews every entry.

1. Find what Voxtype actually heard. Don't guess the mishearing:
   `journalctl --user -u voxtype -o cat | grep Transcribed: | tail -50`
   If the log doesn't show the word, ask the user what it typed instead.
2. Pick the fix:
   - The correct spelling goes in `[whisper] initial_prompt`, the comma list of words to expect. Use this by default.
   - Add `"heard" = "meant"` under `[text.replacements]` only when the log shows the same wrong spelling more than once.
3. Open a PR on the dotfiles repo from a new branch off `origin/main`. Put the log lines you used in the PR description.
4. Tell the user it applies after merge, once they rerun the `voxtype` module (`./install.sh voxtype`).

---
name: dictionary
description: Teach Voxtype dictation a word it keeps mishearing by opening a dotfiles PR. Use when the user says dictation got a word wrong, e.g. "that should have said Omarchy, fix it in my dotfiles".
---

Add the word to `voxtype/config.toml` in the dotfiles repo and open a PR. Check what was actually heard first with `journalctl --user -u voxtype -o cat | grep Transcribed:`; never guess a mishearing.

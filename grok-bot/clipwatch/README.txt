Grok Bot paste freeze helpers (X11 / Electron 42 + Chrome 148)

Upstream: Electron PR #54914 (still draft as of 2026-10-25) restores a 5s
SelectionRequester timeout. Until Grok Bot ships a build with that, pasting
can hang forever if the clipboard owner never answers ConvertSelection.

Services (user systemd):
  clipguard: if a new CLIPBOARD owner ignores TARGETS for 1.5s, re-own with
             plain text so Grok Bot never queues forever (loses that copy).
  clipwatch: log owner changes + answer latency (journalctl --user -u clipwatch)

If Grok Bot is ALREADY frozen:
  ~/.local/share/clipwatch/unstick.sh
  then try Ctrl+V again; restart the app only if still stuck.
  Optionally: ~/.local/share/clipwatch/freeze-diag.sh -> ~/grok-freeze-HHMMSS.txt

Enable (grok-bot/install.sh in the dotfiles does this):
  systemctl --user enable --now clipguard.service clipwatch.service

Disable / remove:
  systemctl --user disable --now clipguard clipwatch
  rm -rf ~/.local/share/clipwatch

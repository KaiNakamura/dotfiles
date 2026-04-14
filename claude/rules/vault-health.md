# Vault Health

After any session that writes files to `~/repos/thoughts/` (hub files, log entries,
iterations.md, etc.), run:

  cd ~/repos/thoughts && obsidian orphans total && obsidian unresolved total

Expected: orphans = 1 (README.md), unresolved = 0.

If either count is unexpected, run `/vault-health` for a detailed report and fix
before ending the session.

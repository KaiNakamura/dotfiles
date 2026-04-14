---
name: vault-health
description: Audit the Obsidian thoughts vault for orphans, unresolved links, and deadends
argument-hint: ""
---

Audit the Obsidian thoughts vault for health issues. Read-only — no vault files are modified.

Vault path: `~/repos/thoughts/` (hardcoded, single vault).

## Steps

1. Run `obsidian orphans total` from `~/repos/thoughts/`
   - Expected: 1 (README.md only)
   - If > 1: run `obsidian orphans` and identify unexpected files

2. Run `obsidian unresolved total`
   - Expected: 0 (some false positives from coordinate strings in log entries are acceptable)
   - If > 0: run `obsidian unresolved verbose format=json`, parse and display as:
     ```
     Broken link: "target text"
       Source: path/to/file.md
     ```

3. Run `obsidian deadends total`
   - Informational only — no action required

4. Output summary:
   ```
   Vault Health (~/repos/thoughts)
   ─────────────────────────────────────
   Orphans:    N  [checkmark or issue count]
   Unresolved: N  [checkmark or issue count]
   Deadends:   N  (informational)
   ```

5. If issues found, suggest fixes:
   - Orphan artifact → check parent `log.md` has a link to it
   - Orphan `log.md` → check `iterations.md` has `[[{slug}/iteration-NN/log|log]]` link
   - Unresolved link → find source file, fix or remove the broken wikilink

## Success Criteria

- Health report printed with counts for all three metrics
- Unexpected orphans and unresolved links listed with source context
- No vault files modified

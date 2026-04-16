---
name: vault-health
description: Audit the Obsidian thoughts vault for orphans, unresolved links, isolated hubs, and structural issues
argument-hint: ""
---

Audit the Obsidian thoughts vault and surface anything that looks off. No vault files are modified.

Vault path: `~/repos/thoughts/` (hardcoded, single vault).

## Steps

### 1. Hub Enumeration

Use both methods to discover project hubs, then cross-check them against each other.

**Path-based:** run `find ~/repos/thoughts/projects/ -name "problem.md"`. For each result, derive the project dir (strip `/problem.md`) and expected hub path (`<dir>/<slug>.md`, where slug is the basename of the dir).

**Tag-based:** run `obsidian tag name=project verbose`. This gives all files tagged `[project]`.

Look for mismatches between the two lists:
- A dir found via path where the expected `<slug>.md` hub file doesn't exist on disk
- A hub file found via path where `obsidian property:read name=tags path=<hub>` doesn't include `project`
- A file found via tags where `<parent>/problem.md` doesn't exist (tagged as a project but no real project structure behind it)

Note any of these as structural issues.

### 2. Isolated Hub Check

For each hub in the reconciled list, run `obsidian links path=<hub>` and check whether any of its outgoing links point into `repos/`. A hub with no `repos/` link is potentially isolated from the rest of the graph.

For each potentially isolated hub, read the file and use judgment: does the project clearly have no external code repo? Look for signals like notes about vault-internal changes, brainstorming-only projects with no codebase, or anything else that makes the absence of a repo link obviously intentional. If it looks intentional, note it as such. If it's ambiguous or looks like a forgotten link, flag it.

### 3. Orphans

Run `obsidian orphans total`. Expect 1 (README.md only). If there are more, run `obsidian orphans` to see what's unexpected.

### 4. Unresolved Links

Run `obsidian unresolved total`. Expect 0, though some false positives from coordinate strings in log entries are acceptable. If there are any, run `obsidian unresolved verbose format=json` to find the sources and targets.

### 5. Deadends

Run `obsidian deadends total`. Just informational, no action needed.

### 6. Report

Share what you found across all five checks. For each area, note whether things look clean or call out what seems off. For isolated hubs that look intentional, briefly mention them so it's clear they were checked. For anything genuinely problematic, describe it clearly enough that it's easy to fix in a follow-up.

## Success Criteria

- All five checks run and findings reported
- Anything that looks like a real issue is surfaced with enough context to act on
- Intentional edge cases (like repos with no external codebase) are noted so they don't get flagged repeatedly
- No vault files modified

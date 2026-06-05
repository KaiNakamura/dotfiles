---
name: vault-health
description: Audit the Obsidian thoughts vault for orphans, unresolved links, isolated hubs, and structural issues, fixing what can be safely fixed
argument-hint: ""
---

Audit the Obsidian thoughts vault, fix anything that can be safely fixed, and report the rest. Safe fixes are mechanical ones: broken link formats, missing tags, unresolved links with an obvious intended target, missing structural stubs. Anything requiring judgment gets reported back so the user can provide guidance for how to fix properly.

Vault path: `~/repos/thoughts/` (hardcoded, single vault).

## Steps

### Hub Enumeration

Use both methods to discover project hubs, then cross-check them against each other.

**Path-based:** run `find ~/repos/thoughts/projects/ -name "problem.md"`. For each result, derive the project dir (strip `/problem.md`) and expected hub path (`<dir>/<slug>.md`, where slug is the basename of the dir).

**Tag-based:** run `obsidian tag name=project verbose`. This gives all files tagged `[project]`.

Look for mismatches between the two lists and try and find structural issues, such as:
- A dir found via path where the expected `<slug>.md` hub file doesn't exist on disk
- A hub file found via path where `obsidian property:read name=tags path=<hub>` doesn't include `project`
- A file found via tags where `<parent>/problem.md` doesn't exist (tagged as a project but no real project structure behind it)

### Isolated Hub Check

For each hub in the reconciled list, run `obsidian links path=<hub>` and check whether any of its outgoing links point into `repos/`. A hub with no `repos/` link is potentially isolated from the rest of the graph.

For each potentially isolated hub, read the file and use judgment: does the project clearly have no external code repo? Look for signals like notes about vault-internal changes, brainstorming-only projects with no codebase, or anything else that makes the absence of a repo link obviously intentional. If it looks intentional, note it as such. If it's ambiguous or looks like a forgotten link, flag it.

### Orphans

Run `obsidian orphans` to identify orphaned notes. Some files like the README are fine, but see what else is unexpected.

### Unresolved Links

Run `obsidian unresolved total`, expect 0
- If there are any, run `obsidian unresolved verbose format=json` to find the sources and targets.
- If some are false positives (e.g., a bbox string like `[[x1, x2], [y1, y2]]`) wrap in inline code so they get ignored

### Fix and Report

Fix the safely fixable issues found across checks, then share what was done and what remains. For each area, note whether things look clean, what was fixed, or what seems off. For things that look intentional, briefly mention them so it's clear they were checked. For anything that needs judgment, describe it clearly enough that the user can decide what to do.

## Success Criteria

- All checks run
- Safely fixable issues are fixed, with the fixes summarized back to the user
- Anything needing judgment is surfaced with enough context to act on, not guessed at
- Intentional edge cases (like projects with no external codebase) are noted so they don't get flagged repeatedly

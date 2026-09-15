---
name: vault-health
description: Audit the Obsidian thoughts vault for orphans, unresolved links, isolated hubs, and structural issues, fixing what can be safely fixed
argument-hint: ""
---

Audit the Obsidian thoughts vault, fix anything that can be safely fixed, and report the rest. Safe fixes are mechanical ones: broken link formats, missing tags, unresolved links with an obvious intended target, missing structural stubs. Anything requiring judgment gets reported back so the user can provide guidance for how to fix properly, never guessed at.

Start from the vault's own root description. That file is the specification, and anything on disk contradicting it is a finding. Do not audit against conventions you remember: they drift, and the vault's description is the authority even when you disagree with it.

Look for the ways a linked vault decays. Notes nothing points at. Links pointing at nothing. Hubs cut off from the rest of the graph. Structure that exists on disk but not in the description, or in the description but not on disk. Enumerate things more than one way and cross-check the two lists against each other, because the interesting failures are the disagreements between two methods, and a single method cannot find them. The `obsidian` CLI can query the vault's link graph directly, which is the cheapest second method available.

A vault also decays outward, where it points at code and tickets. `th doctor --json` reports every node whose `repo:`, `branch:` or `links:` does not resolve on this machine, which is a third enumeration method and the only one that checks the world outside the vault. Fill in what the vault already knows: a `repo:` the body's `## Repos` wiki-link already names, a `branch:` matching exactly one worktree of that repo, a URL sitting in body prose that belongs in `links:`. Report the rest rather than guessing, because the ambiguous cases are ambiguous for real reasons: a repo that is not cloned here may be deliberate, two candidate branches means the head is stale in a way only the user can settle, and a missing checkout is a decision to clone, not a repair.

Some findings are intentional. A project with no external codebase has no repo link, and that is correct. Some unresolved links are false positives, like a bbox string that happens to look like a wiki-link, which can be wrapped in inline code so they get ignored. For things that look intentional, briefly mention them so it's clear they were checked and the same thing does not get re-flagged on every run.

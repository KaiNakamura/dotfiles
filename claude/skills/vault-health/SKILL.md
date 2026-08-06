---
name: vault-health
description: Audit the Obsidian thoughts vault for orphans, unresolved links, isolated hubs, and structural issues, fixing what can be safely fixed
argument-hint: ""
---

Check the vault against what it says about itself, fix what is mechanically safe, and report the rest.

Start from the vault's own root description. That file is the specification, and anything on disk contradicting it is a finding. Do not audit against conventions you remember: they drift, and the vault's description is the authority even when you disagree with it.

Look for the ways a linked vault decays. Notes nothing points at. Links pointing at nothing. Hubs cut off from the rest of the graph. Structure that exists on disk but not in the description, or in the description but not on disk. Enumerate things more than one way, because the interesting failures are the disagreements between two methods, and a single method cannot find them. The `obsidian` CLI can query the vault's link graph directly, which is the cheapest second method available.

Fix only the mechanical: a malformed link, a missing tag, an unresolved link with exactly one obvious intended target, a missing structural stub. Anything needing judgment gets reported with enough context for the user to decide, never guessed at.

Some findings are intentional. A project with no external codebase has no repo link, and that is correct. Say so explicitly, so the same thing does not get re-flagged on every run.

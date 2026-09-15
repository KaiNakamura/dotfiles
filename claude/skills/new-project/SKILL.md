---
name: new-project
description: Create a new project in the Obsidian thoughts vault
argument-hint: "[slug] [optional: group path, e.g. cyvl/c7]"
---

Create a new project in the Obsidian thoughts vault with full scaffolding.

Ask for what you cannot infer: where it belongs, which repos it touches, what the problem is. Do not guess at placement, require an explicit answer. A project filed in the wrong place is harder to fix later than one question is to ask now, because links point at it by then.

Repos are tracked as their own notes so several projects can point at the same one. Reuse the existing note when there is one, and create it when there is not, asking the user for the org and a one-line description.

The problem statement goes in as the user's exact words, the same rule `/problem` follows: no tightening, no cleanup. `/problem` stays its own skill because the statement gets revised as understanding sharpens, long after scaffolding is done.

Output the full path when you are done, so the user can go there and start.

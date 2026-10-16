---
name: notes-vault
description: When a task needs context from the user's personal notes vault (people, habits, hobbies, projects, history)
---

The notes vault is personal and sensitive. Read with care.

1. Run `git -C ~/repos/notes pull --ff-only` before reading. If it fails, say so and read the local copy.
2. Read `AGENTS.md` at the vault root for where things live.
3. Start with the folders your task needs. Search with `rg`; follow `[[links]]` and backlinks (`rg -F '[[Name'`) when they help.
4. Stay on task. Don't browse unrelated areas.
5. Cite the notes you used by path in your answer.
6. Don't quote notes in public places or other repos, and don't bulk copy them. Summarize instead.
7. Write your own output to the thoughts vault, not the notes vault.
8. To change a note, use a branch and a PR. Never commit to main. Never edit daily notes.

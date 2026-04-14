---
name: problem
description: Create or update the problem definition for the current project
argument-hint: "[problem description]"
---

Create or update the problem definition for the current project. Also bootstraps the Obsidian vault entry if this is a new project.

## Steps

1. Derive `slug` from `basename $PWD`
2. Check if `.thoughts/problem.md` exists
   - **Exists (update case):** read it, apply the user's update, write `.thoughts/problem.md`, then sync vault `problem.md` (overwrite `~/repos/thoughts/projects/**/{slug}/problem.md`) — skip vault scaffolding
   - **Does not exist (new project):** proceed to step 3
3. Write `.thoughts/problem.md` with the user's exact problem statement
4. Check vault for existing entry: `find ~/repos/thoughts/projects -name "{slug}.md" -maxdepth 4`
   - Found → vault entry exists, done
   - Not found → scaffold vault entry (steps 5–8)
5. Ask user for group path (e.g., `dotfiles`, `cyvl/spatial`, `kai.nvim`) — no default, require explicit answer
6. Create vault structure at `~/repos/thoughts/projects/{group}/{slug}/`:
   - `{slug}.md` — hub file (see template below)
   - `problem.md` — copy of `.thoughts/problem.md` content
   - `iterations.md` — minimal iterations file (see template below)
   - `iteration-01/log.md` — header `# Iteration 01 Log` + initial log entry
   - `iteration-01/progress.md` — from checkpoint template
   - Empty phase dirs: `iteration-01/{understanding,concepts,plan,implementation}/`
7. Append entry to `~/repos/thoughts/README.md` under `## Projects`:
   `- [slug](projects/{group}/{slug}/{slug}.md): one-line problem summary`

## Hub File Template

```markdown
---
tags: [project]
repos:
  - {$PWD}
---
- [[{slug}/problem|problem]]
- [[{slug}/iterations|iterations]]

{one-line problem summary from user}
```

## Iterations File Template

```markdown
# Iterations

- [[{slug}]]
```

## Success Criteria

- `.thoughts/problem.md` exists with user's exact words
- For new projects: vault entry scaffolded at `~/repos/thoughts/projects/{group}/{slug}/`
- After vault writes: `obsidian orphans total` stays at 1 (README.md only)

## Guidelines

- Problem statement is user-controlled — use their exact words, do not embellish
- Do not re-scaffold vault structure if entry already exists
- On update: always sync vault `problem.md` to match `.thoughts/problem.md`

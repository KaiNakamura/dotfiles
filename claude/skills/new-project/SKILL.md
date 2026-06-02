---
name: new-project
description: Create a new project in the Obsidian thoughts vault
argument-hint: "[slug] [optional: group path, e.g. cyvl/c7]"
---

Create a new project in the Obsidian thoughts vault with full scaffolding.

## Steps

1. Parse `$ARGUMENTS` for slug and optional group path
2. Full project path: `~/repos/thoughts/projects/<group-path>/<slug>/`
3. Create group folders if they don't exist (`mkdir -p`)
4. Create project structure:
   - `<slug>.md` -- hub file (the project name, matching the folder) with this content:
     ````markdown
     ---
     tags: [project]
     ---
     - [[<slug>/problem|problem]]
     - [[<slug>/iterations|iterations]]
     ````
   - `problem.md` -- prompt user for problem statement; include a backlink nav at the top: `[[<slug>/<slug>|<slug>]]`
   - `iterations.md` -- empty with header `# Iterations`
   - `iteration-01/log.md` -- with header `# Iteration 01 Log` and initial entry
   - `iteration-01/progress.md` -- from checkpoint template
   - Empty phase dirs: `iteration-01/{understanding,concepts,plan,implementation}/`
5. Prompt user for repo name(s). For each repo:
   - Glob `~/repos/thoughts/repos/**/<name>.md` to find an existing repo file
   - If found, add wiki-link to hub body: `[[repos/<org>/<name>|<name>]]`
   - If not found, create a new repo file at `~/repos/thoughts/repos/<org>/<name>.md`:
     - Ask user for GitHub org/owner and a one-line description
     - Frontmatter: `tags: [repo]` and `github: https://github.com/<org>/<name>`
     - Body: the one-line description
     - Then add the wiki-link to the hub
   - List all repo links under a `Repos:` heading in the hub body
6. Output the full path so user can `cd` to it

## Success Criteria

- Project directory exists with all structural files
- Hub file has repo mappings (or empty if no repos)
- `problem.md` has problem statement

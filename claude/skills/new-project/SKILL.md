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
   - `<slug>.md` -- hub file (the project name, matching the folder) with frontmatter:
     ```yaml
     ---
     repos: []
     ---
     ```
   - `problem.md` -- prompt user for problem statement
   - `iterations.md` -- empty with header `# Iterations`
   - `iteration-01/log.md` -- with header `# Iteration 01 Log` and initial entry
   - `iteration-01/progress.md` -- from checkpoint template
   - Empty phase dirs: `iteration-01/{understanding,concepts,plan,implementation}/`
5. Prompt user for repo paths, populate hub file `repos:` frontmatter
6. Append a line to `~/repos/thoughts/README.md` under the `## Projects` heading: `- [slug](projects/<group-path>/<slug>/<slug>.md): one-line problem summary`
7. Output the full path so user can `cd` to it

## Success Criteria

- Project directory exists with all structural files
- Hub file has repo mappings (or empty if no repos)
- `problem.md` has problem statement

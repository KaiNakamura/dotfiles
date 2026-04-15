# Shared Thoughts Context

Shared context between agents lives in a centralized Obsidian vault at `~/repos/thoughts/`. Claude is launched from a project folder within the vault. Be selective when reading artifacts. Use `log.md` entries and artifact slugs to judge relevance before reading full files.

## Obsidian Basics

This vault is an [Obsidian](https://obsidian.md) vault. Key things agents should know:

- **Wiki-links**: `[[target]]` is the cross-reference syntax. Obsidian resolves links by searching the vault -- no leading slash needed. Use the shortest unique path with a display alias: `[[{slug}/note|display name]]`.
- **Frontmatter**: YAML between `---` delimiters at the top of a file. Hub files use `tags: [project]`.
- **File moves**: Moving files via the filesystem (not Obsidian) does not trigger automatic link updates. Prefer not moving files.

## Vault Structure

The vault organizes work into projects under `projects/`:

```
~/repos/thoughts/
├── README.md
├── projects/
│   ├── {group}/             <- folders without problem.md are groups, can be nested arbitrarily deep
│   │   └── {project-name}/  <- folders with problem.md are projects
│   │       ├── {project-name}.md
│   │       ├── problem.md
│   │       └── iteration-01/
│   └── {project-name}/
└── .obsidian/
```

Projects live under `projects/` at any nesting depth. `problem.md` marks a project; folders without it are groups. Discover projects: `projects/**/problem.md`.

## Project Structure

Each project directory follows the Engineering Design Process:

```
{project-name}.md        <- project hub (unique name, repos as wiki-links to repos/ files)
problem.md               <- problem statement (static anchor)
iterations.md            <- cross-iteration summary
iteration-01/
├── log.md               <- chronological record with artifact links
├── progress.md          <- progress summary for handoff
├── understanding/
│   └── understanding-NN-topic.md
├── concepts/
│   └── concepts-NN-topic.md
├── plan/
│   └── plan-NN-topic.md
└── implementation/
    └── implementation-NN-topic.md
```

- `{project-name}.md`: Project hub (see Hub File section)
- `problem.md`: Problem statement
- `iterations.md`: Cross-iteration summary
- `iteration-NN/log.md`: Chronological record of the iteration, with links to artifacts produced
- `iteration-NN/progress.md`: Progress summary for a single iteration
- `iteration-NN/understanding/understanding-NN-topic.md`: Understanding of the problem
- `iteration-NN/concepts/concepts-NN-topic.md`: Potential concepts
- `iteration-NN/plan/plan-NN-topic.md`: Plan for implementation
- `iteration-NN/implementation/implementation-NN-topic.md`: Summary of implementation changes

## Hub File

`{project-name}.md`: project hub, named to match the folder.

**Frontmatter**: `tags: [project]`. Repo paths are tracked in dedicated repo files under `repos/` rather than in hub frontmatter.

**Body**: starts with nav links to problem and iterations, then a `Repos:` section linking to repo files as wiki-links (e.g., `[[repos/org/name|name]]`), then freeform content. Common things to include: important worktrees or branches, relevant paths, external links, or anything else useful for orienting an agent.

### Agent Instructions

1. Use hub body for context and starting points
2. If a path doesn't exist on disk, use judgment (`git worktree list`, `ls`, etc.) to locate actual working directory
3. Don't hard-fail on stale paths, infer and adapt

### Cross-Project Links

Hub files may contain wiki-links to related projects. When these links are relevant to the current task, read the linked hub file for additional context. Use judgment: don't follow every link automatically, and don't follow links recursively. One hop is typical.

**Link format:** Use the shortest unique path. Obsidian searches the vault by suffix matching, so no leading slash needed. Structural filenames (problem, iterations, log, progress) are not unique across projects and need a slug prefix. Artifact filenames are unique by design and can be used bare:
- Hub-to-problem: `[[{slug}/problem|problem]]`
- Hub-to-iterations: `[[{slug}/iterations|iterations]]`
- problem.md back to hub: `[[{slug}/{slug}|{slug}]]`
- Log/progress: `[[{slug}/iteration-01/log|log]]`, `[[{slug}/iteration-01/progress|progress]]`
- Artifact (in log entries): `[[understanding-01-topic]]`, `[[plan-01-topic]]`

## Artifact Versioning

Artifact files are named `type-NN-topic.md` where `NN` is a zero-padded version number and `topic` is a short kebab-case description (e.g., `understanding-01-skill-config.md`). The `NN` number is the primary version identifier, the topic suffix is for human scannability when browsing the directory.

- The current iteration directory (e.g., `iteration-NN/`) is always the highest number
- The most recent version of a file is always the highest `NN`
- To determine the next version: list existing files, take highest `NN`, add 1. If none exist, start at `01`.
- To find the latest file of a type, glob for the prefix (e.g., `understanding-*.md`) and take the highest `NN`

## Iteration Detection

The project directory is divided into subdirectories based on the current iteration (e.g., `iteration-NN/`). A difficult problem may require multiple iterations. For example, maybe we understood the problem, came up with concepts, made a plan, but the implementation didn't work. We would then re-evaluate and begin a new iteration.

The current iteration directory is always the highest number. If there are no iteration directories, this must be the first iteration (i.e., `iteration-01/`).

An agent will never need to read information from a previous iteration. The only necessary cross-iteration information is captured in the `iterations.md` file.

## Iteration Log

Each iteration has a `log.md` that records the chronological progression. Skills append an entry after producing their artifact. Entries are one line each: a brief description of what happened and why, with a link to any artifact produced. User requests and decisions that don't produce artifacts should also be logged.

Entry format: `- {what was done}, [[artifact-filename]]`
For non-artifact entries: `- {what happened or was decided}`

Example:
```
- Researched keybind setup and KWin environment, [[understanding-01-keybinds]]
- User clarified mouse should center on screen, not window
- Generated 5 concepts for cursor warp, [[concepts-01-cursor-warp]]
```

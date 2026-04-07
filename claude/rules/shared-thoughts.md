# Shared Thoughts Context

Shared context between agents lives in the project directory within the Obsidian vault at `~/repos/thoughts/`. When Claude is launched from a vault project folder, all paths are relative to CWD. Be selective when reading artifacts — use `log.md` entries and artifact slugs to judge relevance before reading full files. Avoid loading everything indiscriminately, but feel free to read something if it's relevant to your current task.

## Directory Structure

Each project directory is structured based on pipeline stages that mirror the Engineering Design Process:

```
{slug}.md                <- project hub (unique name, repos in frontmatter)
problem.md               <- problem statement (static anchor)
iterations.md            <- cross-iteration summary
iteration-01/
├── log.md               <- chronological record with artifact links
├── progress.md          <- progress summary for handoff
├── understanding/
│   ├── understanding-01-topic.md
│   ├── understanding-02-topic.md
│   ├── ...
│   └── understanding-NN-topic.md
├── concepts/
│   └── concepts-NN-topic.md
├── plan/
│   └── plan-NN-topic.md
└── implementation/
    └── implementation-NN-topic.md
```

- `{slug}.md`: Project hub (see Hub File section below)
- `problem.md`: Problem statement
- `iterations.md`: Cross-iteration summary
- `iteration-NN/log.md`: Chronological record of the iteration - what the user asked, what was done, with links to artifacts produced
- `iteration-NN/progress.md`: Progress summary for a single iteration
- `iteration-NN/understanding/understanding-NN-topic.md`: Understanding of the problem
- `iteration-NN/concepts/concepts-NN-topic.md`: Potential concepts
- `iteration-NN/plan/plan-NN-topic.md`: Plan for implementation
- `iteration-NN/implementation/implementation-NN-topic.md`: Summary of implementation changes

## Hub File

- `{slug}.md` is the uniquely-named project hub, where `{slug}` matches the project folder name
- Frontmatter contains `repos:` (list of absolute paths to code repos) and `status:` (active/dormant)
- Body contains contextual prose with wiki-links to related projects (`[[other-slug]]`) and key artifacts
- Cross-project links default to `[[slug]]`; path-qualified links allowed for specific artifacts when needed
- Agents read this file to learn which code repos to operate on and pass those paths to sub-agents

## Project Discovery

- Projects live under `~/repos/thoughts/projects/` with arbitrary nesting depth
- `problem.md` is the project marker — group folders don't have one
- Discover a specific project: `projects/**/slug/problem.md`
- Enumerate all projects: `projects/**/problem.md`

## Artifact Versioning

Artifact files are named `type-NN-topic.md` where `NN` is a zero-padded version number and `topic` is a short kebab-case description (e.g., `understanding-01-skill-config.md`). The `NN` number is the primary version identifier, the topic suffix is for human scannability when browsing the directory.

- The current iteration directory (e.g., `iteration-NN/`) is always the highest number
- The most recent version of a file is always the highest `NN`
- To determine the next version: list existing files, take highest `NN`, add 1. If none exist, start at `01`.
- To find the latest file of a type, glob for the prefix (e.g., `understanding-*.md`) and take the highest `NN`

## Iteration Detection

The project directory is divided into subdirectories based on the current iteration (e.g., `iteration-NN/`). Oftentimes, a difficult problem may require multiple iterations to solve. For example, maybe we understood the problem, came up with some concepts, made a plan, but then the implementation didn't work. We would then re-evaluate our approach and begin a new iteration, following the same steps.

The current iteration directory is always the highest number. If there are no iteration directories, then this must be the first iteration (i.e., `iteration-01/`).

An agent will never need to read information from a previous iteration. The only necessary cross-iteration information is captured in the `iterations.md` file.

## Iteration Log

Each iteration has a `log.md` that records the chronological progression. Skills append an entry after producing their artifact. Entries are one line each: a brief description of what happened and why, with a link to any artifact produced. User requests and decisions that don't produce artifacts should also be logged.

Entry format: `- {what was done}, [artifact-filename.md](./phase/artifact-filename.md)`
For non-artifact entries: `- {what happened or was decided}`

Example:
```
- Researched keybind setup and KWin environment, [understanding-01-keybinds.md](./understanding/understanding-01-keybinds.md)
- User clarified mouse should center on screen, not window
- Generated 5 concepts for cursor warp, [concepts-01-cursor-warp.md](./concepts/concepts-01-cursor-warp.md)
```

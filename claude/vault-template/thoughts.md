# Thoughts Vault

This file describes how this vault is laid out. It is the one place that describes it. Skills that write here carry intent only and get their structure from this file, so read it before writing.

Shared context between agents lives in a centralized Obsidian vault at `~/repos/thoughts/`. Claude is usually launched from a folder within the vault.

## Reading Selectively

Read what is relevant to the task and skip what is not. Loading every note in a node crowds out room to work.

- Use `log.md` as an index. Its entries describe what each note covers, so relevance can be judged without opening the file.
- Read the log before the notes it points at, and take its verdict over a note's own confidence. A note records what was believed when it was written; the log records what happened after.
- When in doubt, read it. A missed piece of context costs more than an unnecessary read. The exception is orienting at the start of a session, where the cost runs the other way: read the least that lets you hold the thread, and pull the rest when a task actually needs it.

## Obsidian Basics

This vault is an [Obsidian](https://obsidian.md) vault. Key things agents should know:

- **Wiki-links**: `[[target]]` is the cross-reference syntax. Obsidian resolves links by searching the vault -- no leading slash needed. Use the shortest unique path with a display alias: `[[{slug}/note|display name]]`.
- **Frontmatter**: YAML between `---` delimiters at the top of a file.
- **File moves**: Moving files via the filesystem (not Obsidian) does not trigger automatic link updates. Prefer not moving files.

## Vault Structure

```
~/repos/thoughts/
├── thoughts.md          <- this file: how this vault is structured
├── repos/               <- repo pointers
├── knowledge/           <- confirmed truths, atomic and revisable
└── projects/            <- the problem tree
```

Everything under `projects/` is the same shape at every level, nested as deep as the work needs. There is no distinction between a group and a project: a folder that only holds other folders is still a node with its own head and log, and it usually has something worth saying.

## Node Structure

A node is a directory. It holds a head file named after the directory, a `log.md`, numbered notes, and child node directories of identical shape.

```
projects/cyvl/                                  <- cyvl is a real node, not an inert folder
├── cyvl.md
├── log.md
└── c9-satellite-adjusted-slam/
    ├── c9-satellite-adjusted-slam.md           <- head
    ├── log.md                                  <- tail
    ├── 01-understanding-recompute-drift.md
    ├── 02-plan-disk-containment.md
    ├── 03-triage-open-items.md
    └── stitch-proportionality/                 <- child node, identical shape
        ├── stitch-proportionality.md
        ├── log.md
        └── 01-...
```

Two files carry the node, and they are opposites:

| | Write mode | Holds |
|---|---|---|
| Head | mutable | what this problem is, and where it stands now |
| `log.md` | append-only | the chronological trail |

Nothing hand-maintains a summary across children. A rollup is derived by walking child statuses, so it is generated when someone asks for it and never stored. There are no phase subfolders: chronology is the file order in the node directory.

## Node Head

Named after its directory, so `c9-bugsmash/c9-bugsmash.md`. Obsidian disambiguates by path when a name collides with one under `knowledge/`.

Frontmatter carries status, and optionally `tags: [project]` for graph coloring:

```yaml
---
status: in-progress
tags: [project]
---
```

Status vocabulary is `todo`, `in-progress`, `blocked`, `deferred`, `done`, `canceled`. It is open-ended. Something one-off like `waiting-on-casey` is fine and is shown as written, never treated as an error.

The body holds two things that are edited differently. The problem statement is written once and revised only when the problem itself changes. Current state is overwritten every time the node is checkpointed, and describes now rather than history, because the log already has history.

The body also carries pointers: repo as a wiki-link to its note under `repos/`, plus branch and worktree path. All three are hints. If a path is not there, use judgment (`git worktree list`, `ls`) to find the real one. A stale hint costs a lookup, not a failure, so infer and adapt rather than trusting or correcting it.

## Note Naming

`NN-<slug>.md`. `NN` orders the note within its node directory and is numbered per node, not per type or per vault. To get the next number, list the directory, take the highest, add one.

The slug usually names what the note is, but nothing enforces it, so `01-understanding-recompute-drift.md` and `03-triage-open-items.md` sit in the same directory and both read right.

This means there is no reliable glob for "the latest plan." That is deliberate. Work it out from the directory listing and the log the way a person would.

Notes may carry `tags:` frontmatter for Obsidian graph coloring, one of `understanding`, `concepts`, `plan`, `implementation`. Omitting it means untyped, which is correct for a note that is not one of those. Never depend on a tag being present.

## Writing Notes

Each phase of work writes one note into the current node directory as `NN-<slug>.md`. The skill decides what to say; this file decides where it goes and what shape it takes. Shapes live in `templates/` next to this file. Follow the template for the note being written.

| Phase | Where it goes |
|---|---|
| Problem definition | the head's problem statement |
| Understanding, concepts, plan, implementation | `NN-<slug>.md` in the node directory |
| Checkpoint | the head's current state, overwritten |

Three conventions apply to everything written here:

- **Notes are written for someone scanning, not studying.** Same brevity the conversation gets: no preamble, no restating the request, no summary of what was just written. If a line carries neither a fact nor a reason, cut it. Keep the reasoning though, since this gets read cold with nobody around to ask.
- **The user's words are preserved verbatim.** Copy the prompt that prompted the note into a `## User Request (verbatim)` blockquote at the top, unedited. The user's own wording carries authority that a paraphrase loses.
- **The log gets an entry.** Append one line describing what happened, linking the note if there was one.

## Log

`log.md` records how the work got here, so a reader with no memory of it can start at the top and arrive at the present. It is not an index of notes. The entries that carry the most are the ones with no note attached: rejections, reversals, decisions, what the user actually said.

Entry format: `- {what was done}, [[note-filename]]`
For non-note entries: `- {what happened or was decided}`

```
- Researched keybind setup and KWin environment, [[01-understanding-keybinds]]
- User clarified mouse should center on screen, not window
- Generated 5 concepts for cursor warp, [[02-concepts-cursor-warp]]
```

One sentence on one line. An entry records what happened, not what the thing is: the note or head it points at already holds the content, and an entry that duplicates them goes stale where nobody thinks to look for it.

### Correcting the Record

Work goes wrong. Premises turn out false, decisions reverse, sometimes a whole stretch dies at once. A correction only counts if it lands where the next reader already looks, which is the log. What makes it worth writing is naming what is dead specifically enough that nobody rebuilds it.

Fixing the note itself is fine. Deleting one is not: the record is more useful honest than tidy.

## Creating a Node

A node lives wherever it belongs in the tree, which is asked for rather than guessed. It starts with two files:

- `{slug}.md` -- the head:
  ```markdown
  ---
  status: todo
  tags: [project]
  ---
  # {Title}

  {the problem statement, in the user's own words}

  ## Current State

  Just created.

  ## Repos

  - [[repos/{org}/{name}|{name}]]
  ```
- `log.md` -- a first entry saying why this node exists

## Child Node vs Numbered Note

Default to a numbered note in the node already open. A child node is warranted only when the work has shifted to a genuinely different subproblem, either because the agent spots the shift and suggests it or because the user asks for one. Otherwise the tree goes deep by accident and nothing is where anyone expects.

When a child is created, its parent mentions it once, in the parent's log, at birth, with the reason:

```
- Split out stitch proportionality as a subproblem, recompute drift and warp shape are independent, [[stitch-proportionality]]
```

That is the only place the parent tracks its children. Everything else about a child is discoverable by looking at the directory.

## Iterating

Sometimes an approach turns out wrong, sometimes the work just moves to a genuinely different step, and either way it gets reframed against the original problem. That is a marker, not a structural event: a log entry giving the reason, and a rewritten current state in the head. Work continues in the same node. It does not create a sibling node, a new directory, or a new numbering sequence.

Where an approach died, the diagnosis is the whole point. A record that says the approach was abandoned without saying what was wrong with it costs a reader time and tells them not to repeat a mistake it never named. Where nothing died, say so by not saying it.

## Knowledge

`knowledge/` holds things that are true, as opposed to things that were believed during a piece of work. Notes there are atomic, unnumbered, and revised in place as understanding improves.

Nothing is written here without the user confirming it. The agent proposes what it believes has been established, the user says yes, and only then does it get written. Speculation stays at problem level, in the node where it came up. The cost of a wrong note in `knowledge/` is that it gets trusted later by something that has no way to check.

One level of folders, grouped by subject domain, no deeper:

```
knowledge/
├── general/            <- DRY, monorepo boundaries, git patterns
├── cyvl/               <- what Cyvl is, firewatch, pitstop, PCI
├── spatial/            <- keyed to the spatial repo
└── dotfiles/
```

Agents arrive at knowledge by following a link from the work they are already doing, never by browsing, so the hierarchy carries no retrieval weight and can be shallow and slightly wrong at no cost. Never let the choice of folder hold up a checkpoint. Default to `general/` and move it later; a wrong folder costs nothing and a missing note costs a lot.

## Repo Notes

Repos are their own notes under `repos/{org}/{name}.md`, so several nodes can link the same repo and the durable facts about it live in one place.

```markdown
---
tags: [repo]
github: https://github.com/{org}/{name}
---
One line on what this repo is.
```

Repos usually sit at `~/repos/{name}/`, sometimes at a worktree nested inside. As with the hints in a node head, a stale local path is not a failure.

## Links

Use the shortest unique path. Obsidian searches the vault by suffix, so no leading slash is needed.

- Node head: `[[{slug}]]`, since a head is named after its directory and is usually unique
- A node's log: `[[{slug}/log|log]]`, since `log.md` is not unique
- A note: `[[NN-slug]]` bare, unless the same name exists in another node, in which case prefix it: `[[{node}/NN-slug|...]]`

A head may link to related nodes elsewhere in the tree. When such a link is relevant, read it. Use judgment: not every link, and not recursively. One hop is typical.

## Legacy Layout

Most of the vault predates this structure and has not been converted. Those projects hold `problem.md`, `iterations.md`, and `iteration-NN/` directories containing `log.md`, `progress.md`, and `understanding/`, `concepts/`, `plan/`, `implementation/` subfolders with notes named `type-NN-topic.md`.

They read fine as they stand. Do not convert one as a side effect of working in it, and do not treat the mixture as a problem to fix. New nodes follow the structure above. This section goes away when the vault is migrated.

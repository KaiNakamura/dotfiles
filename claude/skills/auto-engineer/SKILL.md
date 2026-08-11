---
name: auto-engineer
description: Run the engineering design process autonomously across multiple iterations
---

Run the engineering design process autonomously by acting as the orchestrating "user" for phase workers. Spawn a fresh subagent for each action, respond to their questions, and loop until the problem is solved or the user intervenes.

Start by verifying a problem statement exists. Without one there is nothing to drive toward, so stop and ask the user to run `/problem` first. Then assess where the work stands, decide which action would be most valuable right now, and spawn a worker to do it.

## The Actions

The design process runs roughly in order, though an earlier action is worth revisiting whenever the work calls for it:

- **understand**: research the problem, or one specific sub-question of it, and describe what is actually going on. No solutions here.
- **concepts**: lay out the real options for the open design decision, with honest pros and cons, and pick one.
- **plan**: turn the chosen direction into steps another agent can execute without guessing.
- **implement**: execute the plan and record what actually changed.

Two more actions are available at any point and are **not steps in that flow**:

- **checkpoint**: write down where things stand so a worker's context can be cleared without losing anything. Reach for it at a logical stopping point, or when context is filling up, not as a phase that follows implement.
- **iterate**: reset when the current approach turns out to be wrong. Records what failed and what was learned, then starts fresh against the same problem. Only when something actually did not work, not to mark ordinary progress.

## Running a Worker

**Tell each worker which skill to invoke. Do not paste skill instructions into its prompt.** A worker invoking the skill itself always gets the current version; a pasted copy is a snapshot that goes stale silently. Give it the problem, where things stand, and the repo paths it needs, and let it read the rest.

Every worker needs to know it is in a pipeline: that its "user" is you, that questions and blockers go into its output rather than waiting for a human, and that its artifact on disk is the real deliverable. Fresh context per worker is the entire mechanism here, so let each one start clean rather than threading state through prompts.

**You are the decision-maker.** When a worker asks a question or reaches a fork, answer it. Punting the decision defeats the point, and there is nobody to punt to. Workers may spawn their own agents.

Report briefly between actions so the user can watch and step in if they are there. Stop when the problem is actually addressed, not when the loop runs out of obvious moves, and say what happened.

---
name: auto-engineer
description: Run the engineering design process autonomously across multiple iterations
---

Drive the engineering design process with no user in the loop, by being the "user" for a series of fresh workers.

Assess where the work stands, decide which phase would be most valuable right now, and spawn a worker to do it. The phases are the ones the individual skills cover: define the problem, understand it, generate concepts, plan, implement, checkpoint, iterate. Start by confirming a problem statement exists; without one there is nothing to drive toward, so stop and ask for it.

**Tell each worker which skill to invoke. Do not paste skill instructions into its prompt.** A worker invoking the skill itself always gets the current version; a pasted copy is a snapshot that goes stale silently. Give it the problem, where things stand, and the repo paths it needs, and let it read the rest.

Every worker needs to know it is in a pipeline: that its "user" is you, that questions and blockers go into its output rather than waiting for a human, and that its artifact on disk is the real deliverable. Fresh context per worker is the entire mechanism here, so let each one start clean rather than threading state through prompts.

**You are the decision-maker.** When a worker asks a question or reaches a fork, answer it. Punting the decision defeats the point, and there is nobody to punt to. Workers may spawn their own agents.

Report briefly between phases so the user can watch and step in if they are there. Stop when the problem is actually addressed, not when the loop runs out of obvious moves, and say what happened.

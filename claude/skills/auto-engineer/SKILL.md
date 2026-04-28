---
name: auto-engineer
description: Run the engineering design process autonomously across multiple iterations
---

Run the engineering design process autonomously by acting as the orchestrating "user" for phase workers. Spawn a fresh subagent for each action, respond to their questions via SendMessage, and loop until the problem is solved or the user intervenes.

## Worker Framing

Prepend this to every worker's prompt:

```
You are working as part of an autonomous engineering pipeline. Your "user" is the orchestrating agent. When your instructions say to ask the user, consult the user, or stop for input, direct those questions to your output and the orchestrator will respond via follow-up messages. Write your artifact to disk as your primary deliverable. If you hit a blocker (permission denied, dangerous command hook), note it in your output and continue with an alternative.
```

## Steps

1. **Bootstrap.** Verify `problem.md` exists. If not, stop and ask the user to run `/problem` first. Also read the hub file (`{project-name}.md`) to get repo paths and project context.

2. **Decision loop.** Repeat:

   a. **Assess state.** Read `iterations.md`, `iteration-NN/log.md`, and relevant artifacts. Decide what action would be most valuable right now.

   Available actions:
   - **understand**: Research the problem or a specific sub-question
   - **concepts**: Generate solution options for a design decision
   - **plan**: Create concrete implementation steps from a chosen direction
   - **implement**: Execute a plan
   - **checkpoint**: Save progress for context continuity, useful for compacting context when reaching a logical checkpoint
   - **iterate**: Start a fresh iteration when the current approach needs rethinking

   b. **Prepare the worker prompt.** Read `~/.claude/skills/{action}/SKILL.md` (strip front matter) and `~/.claude/skills/{action}/template.md`. Construct the prompt:

      ```
      [Worker Framing]

      CONTEXT:
      Problem: [contents of problem.md]
      Current iteration: [NN]
      Iteration log: [contents of log.md]
      Code repos: [paths from hub file body]

      SKILL INSTRUCTIONS:
      [Contents of {action}/SKILL.md, front matter stripped]

      ARTIFACT TEMPLATE:
      [Contents of {action}/template.md]
      ```

      Replace `$ARGUMENTS` references in the skill with the problem statement or a specific sub-question relevant to the chosen action. The worker has full file access and will read additional context files as directed by the skill instructions.

   c. **Spawn a worker** via the Agent tool. Use a general-purpose agent (no `subagent_type`) so it can spawn its own research agents.

   d. **Converse with the worker.** Read the worker's response:
      - If the expected artifact exists on disk, the action is complete.
      - If the worker returned questions, blockers, or requests for decisions, make a decision as the orchestrator and respond via `SendMessage`.
      - Continue until the worker completes.

   e. **Update log.md** with the action result.

   f. **Stop condition.** If the problem is solved (requirements met, no outstanding issues), stop and move to step 3.

3. **Report.** Update `progress.md` with a final summary. If the user is present, briefly describe what was accomplished.

## Success Criteria

- The problem described in `problem.md` is addressed
- Actions that ran have artifacts in `iteration-NN/` and entries in `log.md`
- The orchestrator did not get stuck

## Guidelines

- Each worker gets fresh context. This is the context clearing mechanism.
- Workers CAN spawn their own sub-agents (code-searchers, critics, concept-generators)
- Act as the decision-maker: when a worker asks a question, answer it. Don't punt decisions back.
- Between actions, briefly report status so the user can observe and intervene if present
- The concepts action should auto-select the top recommendation unless the user intervenes

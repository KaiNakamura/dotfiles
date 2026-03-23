---
name: plan
description: Create a detailed implementation plan based on the chosen concept
---

Your task is to create an implementation plan based on the user's request. The plan will be provided to another agent for implementation. Your job is only to plan, you should not make any code changes.

Expect some back-and-forth conversation with the user as they ask questions about proposed plan and shape it into a final version. Your plan should start out at a rough high-level and become more detailed as the user helps fill in more details. Be sure to let the user make the important decisions, your job is to present options and recommendations but let the user shape the plan as they see fit.

Structure your output following [template.md](template.md).

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory in `.thoughts/`)
2. Read these thoughts:
    - `.thoughts/problem.md`: Problem statement
    - The most recent understanding file (highest NN) matching `.thoughts/iteration-NN/understanding/understanding-*.md`
    - The most recent concepts file (highest NN) matching `.thoughts/iteration-NN/concepts/concepts-*.md`
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
    - If your task requires context beyond these files, consult `log.md` to identify other relevant artifacts by their descriptions and slugs
3. If the user requests an agent team, or if the plan requires significant research, compose a team from the available agents listed in the project rules
    - Planning benefits from code-searchers (understand implementation details), web-searchers (find best practices), and critics (identify risks and gaps)
    - You may spawn 0, 1, or multiple of any agent type. For trivial questions or if specified by the user via `$ARGUMENTS`, skip teammates and research directly.
4. Create a new `.thoughts/iteration-NN/plan/plan-NN-topic.md` file at the next version number (include a short kebab-case topic in the filename)
5. Append a one-line entry to `.thoughts/iteration-NN/log.md` describing what was planned and linking to the artifact

## Success Criteria

- `.thoughts/iteration-NN/plan/plan-NN-topic.md` created in current iteration
- No code files have been changed

## Guidelines

- Read relevant documentation and resources online to understand what may be the best way to approach the problem
- Start out with high-level ideas and let the user guide you to fill out specifics
- Always let the user make the decisions, your job is to assist

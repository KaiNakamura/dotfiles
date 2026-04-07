---
name: understand
description: Research the codebase to build understanding of the problem, writing findings to an understanding artifact
---

Your task is to thoroughly understand the existing codebase and how it pertains to the user's problem. Carefully analyze the prompt and the codebase to understand what they are asking. Your job is to gather as much context as possible about the problem and understand how to approach it.

Structure your output following [template.md](template.md).

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory)
2. Read these thoughts:
    - `problem.md`: Problem statement
    - `iterations.md`: Cross-iteration summary
    - `iteration-NN/progress.md`: Progress summary for the current iteration
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
    - If your task requires context beyond these files, consult `log.md` to identify other relevant artifacts by their descriptions and slugs
3. Analyze the research question and plan what teammate agents are needed to fully understand the problem
    - Refer to the available agents and team composition guidelines in the project rules to determine what teammates to use
    - You may spawn 0, 1, or multiple of any type. For trivial questions or if specified by the user via `$ARGUMENTS`, skip teammates and research directly.
    - Understanding tasks primarily benefit from code-searchers and web-searchers for broad research. Include critics when validating existing research.
4. Create an agent team and for each teammate, provide:
    - Its specific, focused research question
    - Relevant context: problem summary, current iteration, what is already known
    - Include code repo paths from the hub file frontmatter so agents know where source code lives
    - If the hub file links to related projects, consider whether those projects have relevant findings. Read their hub files if the research question would benefit from cross-project context. Use judgment: don't read unrelated projects.
5. Wait for all agents to complete and collect their text summaries
6. Synthesize all summaries into `iteration-NN/understanding/understanding-NN-topic.md` (include a short kebab-case topic in the filename)
7. Append a one-line entry to `iteration-NN/log.md` describing what was researched and linking to the artifact
8. Ask follow-up questions for clarification if anything remains unclear
9. Clean up the team when done

## Success Criteria

- `iteration-NN/understanding/understanding-NN-topic.md` created in current iteration
- Produce a coherent, unified document, not a concatenation of agent outputs
- No code files have been changed
- Summary returned to user for verification
- Summary does not contain any potential solutions, only an understanding of the problem

## Guidelines

- Ask follow-up questions to the user to clarify unclear parts
- Do not propose solutions, just give an overview of your understanding of the problem

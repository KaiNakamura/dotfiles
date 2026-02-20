---
name: understand
description: Research the codebase to build understanding of the problem, writing findings to a .thoughts artifact
---

Your task is to thoroughly understand the existing codebase and how it pertains to the user's problem. Carefully analyze the prompt and the codebase to understand what they are asking. Your job is to gather as much context as possible about the problem and understand how to approach it.

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory in `.thoughts/`)
2. Read these thoughts:
    - `.thoughts/problem.md`: Problem statement
    - `.thoughts/iterations.md`: Cross-iteration summary
    - `.thoughts/iteration-NN/progress.md`: Progress summary for the current iteration
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
3. Analyze the research question and plan our what teammate agents are needed to fully understand the problem
    - You have access to the following teammate agents:
        - `web-searcher`: Searches the web for documentation, examples, resources, etc. Use when research benefits from consulting external information.
        - `code-searcher`: Searches and reads the local codebase. Use to learn existing code structure, file layout, patterns, or tracing how something is implemented locally.
    - How many teammates of each type are warranted? (You may spawn 0, 1, or multiple of either type. For trivial questions or if specified by the user via `$ARFUMENTS`, skip teammates and research directly.)
4. Create an agent team and for each teammate, provide:
    - Its specific, focused research question
    - Relevant context: problem summary, current iteration, what is already known
5. Wait for all agents to complete and collect their text summaries
6. Synthesize all summaries into `.thoughts/iteration-NN/understanding/understanding-NN.md`
7. Ask follow-up questions for clarification if anything remains unclear
8. Clean up the team when done

## Success Criteria

- `.thoughts/iteration-NN/understanding/understanding-NN.md` created in current iteration
- Produce a coherent, unified document, not a concatenation of agent outputs
- No code files have been changed
- Summary returned to user for verification
- Summary does not contain any potential solutions, only an understanding of the problem

## Guidelines

- Ask follow-up questions to the user to clarify unclear parts
- Do not propose solutions, just give an overview of your understanding of the problem

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
3. Analyze the codebase to understand the user's request
    - Read relevant documentation within the codebase whenever possible
    - Search for relevant documentation online for external tools, packages, etc.
    - Trace identifiers (functions, variables, classes, etc.) as deep as you can
4. Ask follow-up questions for clarification
5. Create a new `.thoughts/iteration-NN/understanding-NN.md` file at the next version number

The user will then verify your understanding is correct. Consider asking follow-up questions back to the user for additional clarification on any unclear parts. Do not change any files and do not propose solutions, just give an overview of your understanding of the problem and await user confirmation that it is correct.

## Success Criteria

- `.thoughts/iteration-NN/understanding-NN.md` created in current iteration
- No code files have been changed
- Summary returned to user for verification
- Summary does not contain any potential solutions, only an understanding of the problem

## Guidelines

- Read relevant documentation and resources online
- Ask follow-up questions to the user to clarify unclear parts

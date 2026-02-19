---
name: read
description: Read specified .thoughts files and summarize them to load context into the session
---

Read specified files from shared thoughts to familiarize yourself with the current context.

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory in `.thoughts/`)
2. Read these thoughts:
    - `.thoughts/problem.md`: Problem statement
    - `.thoughts/iterations.md`: Cross-iteration summary
    - `.thoughts/iteration-NN/progress.md`: Progress summary for the current iteration
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
3. Output a brief summary of what you learned

## Success Criteria

- You have read only the specified files and nothing else
- User receives a summary confirming context was loaded
- No files or directories have been modified

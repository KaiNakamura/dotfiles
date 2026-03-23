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
    - `.thoughts/iteration-NN/log.md`: Chronological narrative of the iteration
    - `.thoughts/iteration-NN/progress.md`: Progress summary for the current iteration
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
3. Based on what you learned, output a brief summary covering:
   - Where the iteration currently stands (what phase, what was last done)
   - Key decisions made so far
   - What the likely next step is
   - Any artifacts the user might want to read for deeper context (reference by name from log entries)

## Success Criteria

- You have loaded relevant context without unnecessarily bloating the context window
- User receives a summary confirming context was loaded
- No files or directories have been modified

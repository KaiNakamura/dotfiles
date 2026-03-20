---
name: iterate
description: Start a new iteration when the current approach needs rethinking
argument-hint: "[reason for iterating]"
---

Start a new iteration for the current task.

When updating `.thoughts/iterations.md`, structure each iteration entry following [template.md](template.md).

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory in `.thoughts/`)
2. If there are no previous iterations, create `iteration-01/` and skip to step 4
3. Otherwise, if there are previous iterations:
   - Append a summary to `.thoughts/iterations.md` that captures the reason we need to reiterate. Our goal is to guide new agents so they don't repeat the same mistakes.
   - Create new iteration directory: `.thoughts/iteration-NN/` (next number)
4. Create `.thoughts/iteration-NN/log.md` with header `# Iteration [NN] Log` and an initial entry describing why this iteration was started
5. Create `.thoughts/iteration-NN/progress.md` following the checkpoint [template.md](../checkpoint/template.md)

## Success Criteria

- `.thoughts/iterations.md` updated with summary of previous iteration (if any)
- New iteration directory created at `.thoughts/iteration-NN/`
- `.thoughts/iteration-NN/log.md` created with initial entry
- `.thoughts/iteration-NN/progress.md` created with context summary
- No other files or directories have been modified

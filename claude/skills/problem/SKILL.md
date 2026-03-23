---
name: problem
description: Create or update the problem definition for the current task
argument-hint: "[problem description]"
---

Create or update the problem definition for the current task.

Structure your output following [template.md](template.md).

## Steps

1. Create `.thoughts/` if it doesn't exist
2. If `.thoughts/problem.md` exists, read it first
3. Based on the user's prompt or `$ARGUMENTS`, create/update `.thoughts/problem.md`

## Success Criteria

- `.thoughts/problem.md` exists with the user's exact problem statement, word-for-word
- No other files or directories have been modified

## Guidelines

- This file is user-controlled - use their exact words
- Do not embellish or expand beyond what the user provides

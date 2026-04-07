---
name: problem
description: Create or update the problem definition for the current task
argument-hint: "[problem description]"
---

Update the problem definition for the current task.

Structure your output following [template.md](template.md).

## Steps

1. If `problem.md` doesn't exist, tell the user to run `/new-project` first
2. If `problem.md` exists, read it first
3. Based on the user's prompt or `$ARGUMENTS`, update `problem.md`

## Success Criteria

- `problem.md` exists with the user's exact problem statement, word-for-word
- No other files or directories have been modified

## Guidelines

- This file is user-controlled - use their exact words
- Do not embellish or expand beyond what the user provides

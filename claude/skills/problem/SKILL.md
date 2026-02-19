---
name: problem
description: Create or update the problem definition for the current task
argument-hint: "[problem description]"
---

Create or update the problem definition for the current task.

## Steps

1. Create `.thoughts/` if it doesn't exist
2. If `.thoughts/problem.md` exists, read it first
3. Based on the user's prompt or `$ARGUMENTS`, create/update `.thoughts/problem.md`

## Success Criteria

- `.thoughts/problem.md` exists with the user's problem statement
- No other files or directories have been modified

## Guidelines

- Keep the problem statement concise but complete
- This file is user-controlled - prioritize using their exact words
- Do not embellish or expand beyond what the user provides

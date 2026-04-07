---
name: checkpoint
description: Save a progress summary capturing the current state for handoff to the next session
---

Your current task is nearing a logical checkpoint, or your context window is approaching its limit. Create a progress summary to ensure continuity and efficiency.

Your progress summary will onboard the next agent instance providing it with all the necessary context to continue seamlessly without repeating prior work or requiring extensive re-analysis. Focus on precision and brevity, ensuring all essential information is present without unnecessary verbosity.

Structure your output following [template.md](template.md).

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory)
2. Generate or update a progress summary at `iteration-NN/progress.md`
3. Append a one-line entry to `iteration-NN/log.md` noting the checkpoint

## Success Criteria

- `iteration-NN/progress.md` updated in current iteration
- All critical context captured for handoff
- No other files or directories have been modified

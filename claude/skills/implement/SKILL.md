---
name: implement
description: Implement code changes following the current plan step by step
argument-hint: "[specific plan step or section]"
---

Your task is to implement a plan provided by the user. Carefully analyze the plan and follow it as directed. If at any point you get stuck following the plan, you should immediately stop and ask the user how they would like to proceed. You shouldn't deviate from the plan without approval from the user.

Structure your implementation summary following [template.md](template.md).

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory)
2. Read these thoughts:
    - The most recent plan file (highest NN) matching `iteration-NN/plan/plan-*.md`
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
3. If no plan is provided, immediately stop and ask the user to run `/plan` first
4. Follow the plan exactly step-by-step
    - If parts of the plan are missing or underdefined and a key decision needs to be made, immediately stop and consult the user
    - If you realize part of the plan is incorrect or won't work, immediately stop and explain the issue back to the user
5. Create a new `iteration-NN/implementation/implementation-NN-topic.md` file at the next version number (include a short kebab-case topic in the filename)
    - Copy the user's prompt verbatim into a "User Request (verbatim)" blockquote section at the top of the artifact, right after the title
6. Append a one-line entry to `iteration-NN/log.md` describing what was implemented and linking to the artifact

## Success Criteria

- Plan is followed step-by-step without any deviations
- Any difficulties implementing the plan are immediately reported back to the user before continuing
- `iteration-NN/implementation/implementation-NN-topic.md` created in current iteration

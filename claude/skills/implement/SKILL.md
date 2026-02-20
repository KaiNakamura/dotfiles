---
name: implement
description: Implement code changes following the current plan step by step
argument-hint: "[specific plan step or section]"
---

Your task is to implement a plan provided by the user. Carefully analyze the plan and follow it as directed. If at any point you get stuck following the plan, you should immediately stop and ask the user how they would like to proceed. You shouldn't deviate from the plan without approval from the user.

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory in `.thoughts/`)
2. Read these thoughts:
    - `.thoughts/iteration-NN/plan/plan-NN.md`: The most recent (highest number) plan
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
3. If no plan is provided, immediately stop and ask the user to run `/plan` first
4. Follow the plan exactly step-by-step
    - If parts of the plan are missing or underdefined and a key decision needs to be made, immediately stop and consult the user
    - If you realize part of the plan is incorrect or won't work, immediately stop and explain the issue back to the user
5. Create a new `.thoughts/iteration-NN/implementation/implementation-NN.md` file at the next version number

## Success Criteria

- Plan is followed step-by-step without any deviations
- Any difficulties implementing the plan are immediately reported back to the user before continuing
- `.thoughts/iteration-NN/implementation/implementation-NN.md` created in current iteration

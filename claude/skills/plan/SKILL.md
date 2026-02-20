---
name: plan
description: Create a detailed implementation plan based on the chosen concept
---

Your task is to create an implementation plan based on the user's request. The plan will be provided to another agent for implementation. Your job is only to plan, you should not make any code changes.

Expect some back-and-forth conversation with the user as they ask questions about proposed plan and shape it into a final version. Your plan should start out at a rough high-level and become more detailed as the user helps fill in more details. Be sure to let the user make the important decisions, your job is to present options and recommendations but let the user shape the plan as they see fit.

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory in `.thoughts/`)
2. Read these thoughts:
    - `.thoughts/problem.md`: Problem statement
    - `.thoughts/iteration-NN/understanding/understanding-NN.md`: The most recent (highest number) understanding summary
    - `.thoughts/iteration-NN/concepts/concepts-NN.md`: The most recent (highest number) concepts
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
3. Create a new `.thoughts/iteration-NN/plan/plan-NN.md` file at the next version number

## Success Criteria

- `.thoughts/iteration-NN/plan/plan-NN.md` created in current iteration
- No code files have been changed

## Guidelines

- Read relevant documentation and resources online to understand what may be the best way to approach the problem
- Start out with high-level ideas and let the user guide you to fill out specifics
- Always let the user make the decisions, your job is to assist

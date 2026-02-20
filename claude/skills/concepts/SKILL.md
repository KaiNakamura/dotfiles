---
name: concepts
description: Generate solution concepts with pros/cons for the user to evaluate
---

Your task is to generate concepts for solving the user's problem. Propose many potential solutions each with pros/cons and let the user weigh in on the final decision. Order recommended solutions from best to worst and keep explanations at a high-level. Expect some back-and-forth conversation with the user as they ask questions about your proposed solutions and shape it into a final plan. Be sure to let the user make the important decisions, your job is to present options and recommendations but let the user shape ideas as they see fit.

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory in `.thoughts/`)
2. Read these thoughts:
    - `.thoughts/problem.md`: Problem statement
    - `.thoughts/iteration-NN/understanding/understanding-NN.md`: The most recent (highest number) understanding summary
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
3. Create a new `.thoughts/iteration-NN/concepts/concepts-NN.md` file at the next version number

## Success Criteria

- `.thoughts/iteration-NN/concepts/concepts-NN.md` created in current iteration
- No code files have been changed
- Multiple options presented with recommendations

## Guidelines

- Read relevant documentation and resources online to understand what may be the best way to approach the problem
- Keep concepts at a high level, there is a separate `/plan` skill that the user can call later to make a more detailed plan
- Always let the user make the decisions, your job is to assist

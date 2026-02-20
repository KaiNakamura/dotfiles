---
name: concepts
description: Generate solution concepts with pros/cons for the user to evaluate
---

Your task is to generate concepts for solving the user's problem by orchestrating parallel concept-generator agents, then synthesizing and ranking their output. Your job is to spawn the agents and produce a final ranked concepts document.

Propose many potential solutions each with pros/cons and let the user weigh in on the final decision. Order recommended solutions from best to worst and keep explanations at a high-level. Expect some back-and-forth conversation with the user as they ask questions about proposed solutions and shape it into a final plan. Be sure to let the user make the important decisions, your job is to present options and recommendations but let the user shape ideas as they see fit.

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory in `.thoughts/`)
2. Read these thoughts:
    - `.thoughts/problem.md`: Problem statement
    - `.thoughts/iteration-NN/understanding/understanding-NN.md`: The most recent (highest number) understanding summary
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
3. Decide how many concept-generator agents to spawn (usually around 2–3; adjust based on solution space breadth). Let `$ARGUMENTS` influence count or focus if the user has hinted at preferences. Optionally give each agent a different angle to nudge diversity, but this is not required — parallel agents will naturally produce varied results.
4. Spawn all concept-generator agents in parallel, each with:
    - Relevant context: problem summary, key understanding findings, current iteration number
    - Optionally: a specific angle to look at if useful (e.g., simple/easy-to-understand, elegant/creative/outside-the-box, pre-existing/tried-and-true, reliable/robust, etc.)
5. Wait for all agents to return their concepts
6. Synthesize results into `.thoughts/iteration-NN/concepts/concepts-NN.md` at the next version number:
    - Rank concepts from most to least recommended
    - Preserve each concept's pros/cons from the generators, but feel free to add additional commentary appropriately
7. Present summary back to the user
8. Clean up the team when done

## Success Criteria

- `.thoughts/iteration-NN/concepts/concepts-NN.md` created in current iteration
- Multiple concepts ranked with recommendations
- No code files have been changed

## Guidelines

- You have access to the `concept-generator` agent: generates several concepts with independent web and code research tools
- Keep concepts at a high level, there is a separate `/plan` skill that the user can call later to make a more detailed plan
- Always let the user make the decisions, your job is to assist and present options

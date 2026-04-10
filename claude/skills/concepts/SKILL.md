---
name: concepts
description: Generate concepts for each open design decision, with pros/cons for the user to evaluate
---

Your task is to generate separate concepts for each open design decision in the user's problem by orchestrating concept-generator agents, then synthesizing and ranking their output. Your job is to spawn agents and produce a concepts document organized by decision.

For each design decision, propose multiple potential approaches with pros/cons and let the user weigh in on the final decisoin. Rank recommendations within each decision from best to worst and keep explanations high-level. Expect some back-and-forth conversation with the user as they ask questions about proposed solutions and shape it into a final plan. Be sure to let the user make the important decisions, your job is to present options and recommendations but let the user shape ideas as they see fit.

Structure your output following [template.md](template.md).

## Steps

1. Determine the current iteration (highest `iteration-NN/` directory)
2. Read these thoughts:
    - `problem.md`: Problem statement
    - The most recent understanding file (highest NN) matching `iteration-NN/understanding/understanding-*.md`
    - Any thoughts explicitly specified by the user via `$ARGUMENTS`
    - If your task requires context beyond these files, consult `log.md` to identify other relevant artifacts by their descriptions and slugs
3. Do NOT spawn agents by default. Work directly unless the user explicitly requests it via natural language (e.g., 'agent team of 3', 'use an agent team'). When spawning agents, concept generation primarily uses concept-generator agents, but also benefits from web-searchers and code-searchers to find alternative approaches as well as critics to evaluate and challenge proposed concepts.
4. If spawning agents, decide how many concept-generator agents to spawn based on the requested team size. Let `$ARGUMENTS` influence count or focus if the user has hinted at preferences. Optionally give each agent a different angle to nudge diversity, but this is not required - parallel agents will naturally produce varied results.
5. Spawn all concept-generator agents in parallel, each with:
    - Relevant context: problem summary, key understanding findings, current iteration number
    - Code repo paths from the hub file frontmatter so agents know where source code lives
    - Optionally: a specific angle to look at if useful (e.g., simple/easy-to-understand, elegant/creative/outside-the-box, pre-existing/tried-and-true, reliable/robust, etc.)
6. Wait for all agents to return their concepts
7. Synthesize results into `iteration-NN/concepts/concepts-NN-topic.md` at the next version number (include a short kebab-case topic in the filename):
    - Group concepts by design decision (if there is only one design decision a single group is fine)
    - Rank concepts within each decision from most to least recommended (each decision gets its own recommendation)
    - Preserve each concept's pros/cons from the generators, but feel free to add additional commentary appropriately
8. Append a one-line entry to `iteration-NN/log.md` describing what concepts were generated and linking to the artifact
9. Present summary back to the user
10. Clean up the team when done

## Success Criteria

- `iteration-NN/concepts/concepts-NN-topic.md` created in current iteration
- Concepts organized by design decision, with per-decision recommendations
- No code files have been changed

## Guidelines

- You have access to the `concept-generator` agent: generates several concepts with independent web and code research tools
- Keep concepts at a high level, there is a separate `/plan` skill that the user can call later to make a more detailed plan
- Always let the user make the decisions, your job is to assist and present options

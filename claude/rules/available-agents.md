# Available Agents

The following agents are defined in `claude/agents/` and available for use as teammates in agent teams.

## Research Agents

- `code-searcher`: Searches and reads the local codebase. Use to learn existing code structure, file layout, patterns, or tracing how something is implemented locally. (Model: haiku)
- `web-searcher`: Searches the web for documentation, examples, resources, etc. Use when research benefits from consulting external information. (Model: sonnet)

## Creative Agents

- `concept-generator`: Generates solution concepts with independent web and code research capability. Use during concept generation to explore the solution space in parallel. (Model: sonnet)

## Evaluation Agents

- `critic`: Reviews artifacts (research findings, concepts, plans) for flaws, gaps, incorrect assumptions, and weaknesses. Also challenges direction (devil's advocate) and verifies claims (fact-checking). Use to get a fresh-context evaluation. (Model: sonnet)

## Team Composition Guidelines

When composing an agent team, the main agent decides the mix based on the task:

- **Research-heavy tasks**: More code-searchers and web-searchers
- **Evaluation tasks**: Include critics to review and challenge work
- **Mixed tasks**: Combine researchers and critics as needed
- The main agent always orchestrates, synthesizes, and makes final decisions
- Users can request a specific team size (e.g., "use a team of 5") or specify roles - decide the best mix based on the task context
- For trivial tasks or when specified by the user, skip agents and work directly

## Phase-Specific Recommendations

- **Understand**: Primarily code-searchers and web-searchers for broad research. Include critics when validating existing research.
- **Concepts**: Primarily concept-generators for parallel exploration. Web-searchers and code-searchers to find alternative approaches. Critics to evaluate and challenge proposed concepts.
- **Plan**: Main agent should write the plan but utilize code-searchers for implementation details, web-searchers for best practices, critics to identify risks and gaps, and concept-generators when we have open decision points.

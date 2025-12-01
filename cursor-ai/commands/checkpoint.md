<TASK>
Your current task is nearing a logical checkpoint, or your context window is approaching its limit. Create a progress summary to ensure continuity and efficiency.

Your progress summary will onboard the next agent instance providing it with all the necessary context to continue seamlessly without repeating prior work or requiring extensive re-analysis. Focus on precision and brevity, ensuring all essential information is present without unnecessary verbosity.
</TASK>

<SUCCESS_CRITERIA>
Generate or update a progress summary at `.thoughts/progress.md` that includes:

- **Completed Tasks**: What's been finished with verification status
- **Current State**: Exact file modifications and system status
- **Key Decisions**: Why certain approaches were chosen with rationale
- **Blockers Resolved**: What obstacles were overcome and how
- **Next 2-3 Steps**: Immediate actionable items with specific file paths
- **Context for Handoff**: Critical information the next agent needs
- **Risk Assessment**: Potential issues or dependencies to watch
- **Testing Status**: What's been validated and what still needs testing

Your progress summary should contain all essential information so that the next agent can continue without asking clarifying questions. No important context or decisions should be lost and the summary is immediately usable for handoff.
</SUCCESS_CRITERIA>

<GUIDELINES>
- Keep summary under 500 words but include all critical information
- Use bullet points and structured formatting for quick scanning
- Include specific file paths and line numbers where relevant
- Reference external documentation rather than copying content
</GUIDELINES>

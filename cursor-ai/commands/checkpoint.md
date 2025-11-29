# Checkpoint - Create Progress Summary

Your current task is nearing a logical checkpoint, or your context window is approaching its limit. Create a progress summary to ensure continuity and efficiency.

## When to Use

- After completing 3-4 major tasks
- When context utilization reaches 35-40%
- At natural breakpoints in your work
- Before switching to a different task or taking a break

## Output Requirements

Generate or update a progress summary at `.thoughts/progress.md` that includes:

- **Completed Tasks**: What's been finished with verification status
- **Current State**: Exact file modifications and system status
- **Key Decisions**: Why certain approaches were chosen with rationale
- **Blockers Resolved**: What obstacles were overcome and how
- **Next 2-3 Steps**: Immediate actionable items with specific file paths
- **Context for Handoff**: Critical information the next agent/session needs
- **Risk Assessment**: Potential issues or dependencies to watch
- **Testing Status**: What's been validated and what still needs testing

## Format Guidelines

- Focus on **precision and brevity**
- Keep summary under 500 words but include all critical information
- Use bullet points and structured formatting for quick scanning
- Include specific file paths and line numbers where relevant
- Reference external documentation rather than copying content

## Success Criteria

- Progress summary contains all essential information
- Next agent/session can continue without asking clarifying questions
- No important context or decisions are lost
- File paths and technical details are specific and actionable
- Summary is immediately usable for handoff

## Notes

- This summary will be used by the `/handoff` command to onboard the next session
- Archive detailed logs to separate files if needed to keep summary concise
- Include any temporary workarounds or patches applied
- Document exact versions of dependencies or tools used if relevant


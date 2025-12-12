<TASK>
Your current task is nearing a logical checkpoint, or your context window is approaching its limit. Create a progress summary to ensure continuity and efficiency.

Your progress summary will onboard the next agent instance providing it with all the necessary context to continue seamlessly without repeating prior work or requiring extensive re-analysis. Focus on precision and brevity, ensuring all essential information is present without unnecessary verbosity.

@shared-thoughts

Steps:
1. Determine the branch and current iteration
2. Generate or update a progress summary at `.thoughts/{BRANCH}/iteration-NN/progress.md` that includes:
    - **Completed Tasks**: What's been finished with verification status
    - **Current State**: Exact file modifications and system status
    - **Key Decisions**: Why certain approaches were chosen with rationale
    - **Context for Handoff**: Critical information the next agent needs

Your progress summary should contain all essential information so that the next agent can continue without asking clarifying questions. No important context or decisions should be lost and the summary is immediately usable for handoff.
</TASK>

<SUCCESS_CRITERIA>
- `.thoughts/{BRANCH}/iteration-NN/progress.md` updated in current iteration
- All critical context captured for handoff
- No other files or directories have been modified
</SUCCESS_CRITERIA>

<GUIDELINES>
- @summary-guidelines
</GUIDELINES>

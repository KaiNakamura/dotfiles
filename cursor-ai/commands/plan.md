<TASK> Your task is to create an implementation plan based on the user's request. The plan will be provided to another agent for implementation. Your job is only to plan, you should not make any code changes.

Expect some back-and-forth conversation with the user as they ask questions about proposed plan and shape it into a final version. Your plan should start out at a rough high-level and become more detailed as the user helps fill in more details. Be sure to let the user make the important decisions, your job is to present options and recommendations but let the user shape the plan as they see fit.

@shared-thoughts

Steps:
1. Determine the branch and current iteration
2. Read these thoughts, follow @read-only-specified-thoughts:
    - `.thoughts/{BRANCH}/problem.md`: Problem statement
    - `.thoughts/{BRANCH}/iteration-NN/understanding-NN.md` - The most recent (highest number) understanding summary
    - `.thoughts/{BRANCH}/iteration-NN/concepts-NN.md` - The most recent (highest number) concepts
    - Any thoughts explicitly specified by the user
3. Create a new `.thoughts/{BRANCH}/iteration-NN/plan/plan-NN.md` file at the next number (e.g., if the most recent file is `plan-01.md`, write to `plan-02.md`)
</TASK>

<SUCCESS_CRITERIA>
- `.thoughts/{BRANCH}/iteration-NN/plan/plan-NN.md` created in current iteration
- No code files have been changed
</SUCCESS_CRITERIA>

<GUIDELINES>
- @read-only-specified-thoughts
- Read relevant documentation and resources online to understand what may be the best way to approach the problem
- Start out with high-level ideas and let the user guide you to fill out specifics
- Always let the user make the decisions, your job is to assist
</GUIDELINES>

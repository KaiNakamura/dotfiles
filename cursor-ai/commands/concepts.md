<TASK>
Your task is to generate concepts for solving the user's problem. Propose many potential solutions each with pros/cons and let the user weigh in on the final decision. Order recommended solutions from best to worst and keep explanations at a high-level. Expect some back-and-forth conversation with the user as they ask questions about your proposed solutions and shape it into a final plan. Be sure to let the user make the important decisions, your job is to present options and recommendations but let the user shape ideas as they see fit.

@shared-thoughts

Steps:
1. Determine the branch and current iteration
2. Read these thoughts, follow @read-only-specified-thoughts:
    - `.thoughts/{BRANCH}/problem.md`: Problem statement
    - `.thoughts/{BRANCH}/iteration-NN/understanding-NN.md` - The most recent (highest number) understanding summary
    - Any thoughts explicitly specified by the user
3. Create a new `.thoughts/{BRANCH}/iteration-NN/concepts/concepts-NN.md` file at the next number (e.g., if the most recent file is `concepts-01.md`, write to `concepts-02.md`)
</TASK>

<SUCCESS_CRITERIA>
- `.thoughts/{BRANCH}/iteration-NN/concepts/concepts-NN.md` created in current iteration
- No code files have been changed
- Multiple options presented with recommendations
</SUCCESS_CRITERIA>

<GUIDELINES>
- @read-only-specified-thoughts
- Read relevant documentation and resources online to understand what may be the best way to approach the problem
- Keep concepts at a high level, there is a separate `/plan` commmand that the user can call later to make a more detailed plan
- Always let the user make the decisions, your job is to assist
</GUIDELINES>

<TASK>
Your task is to implement a plan provided by the user. Carefully analyze the plan and follow it as directed. If at any point you get stuck following the plan, you should immediately stop and ask the user how they would like to proceed. You shouldn't deviate from the plan without approval from the user.

@shared-thoughts

Steps:
1. Determine the branch and current iteration
2. Read these thoughts, follow @read-only-specified-thoughts:
    - `.thoughts/{BRANCH}/iteration-NN/plan-NN.md` - The most recent (highest number) plan
    - Any thoughts explicitly specified by the user
3. If no plan is provided, immediately stop and ask the user to run `/plan` first
4. Follow the plan exactly step-by-step
    - If parts of the plan are missing or underdefined and a key decision needs to be made, immediately stop and consult the user
    - If you realize part of the plan is incorrect or won't work, immediately stop and explain the issue back to the user
5. Create a new `.thoughts/{BRANCH}/iteration-NN/implementation/implementation-NN.md` file at the next number (e.g., if the most recent file is `implementation-01.md`, write to `implementation-02.md`)
</TASK>

<SUCCESS_CRITERIA>
- Plan is followed step-by-step without any deviations
- Any difficulties implementing the plan are immediately reported back to the user before continuing
- `.thoughts/{BRANCH}/iteration-NN/implementation/implementation-NN.md` created in current iteration
</SUCCESS_CRITERIA>

<GUIDELINES>
- @read-only-specified-thoughts
- @summary-guidelines
</GUIDELINES>

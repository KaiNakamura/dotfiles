<TASK>
Create or update the problem definition for the current feature branch.

@shared-thoughts

Steps:
1. Detect branch and create `.thoughts/` if it doesn't exist
2. If `.thoughts/problem.md` exists, read it first
3. Based on the user's prompt, create/update `.thoughts/problem.md`
</TASK>

<SUCCESS_CRITERIA>
- `.thoughts/problem.md` exists with the user's problem statement
- No other files or directories have been modified
</SUCCESS_CRITERIA>

<GUIDELINES>
- @read-only-specified-thoughts
- Keep the problem statement concise but complete
- This file is user-controlled - prioritize using their exact words
- Do not embellish or expand beyond what the user provides
</GUIDELINES>

<TASK>
Create or update the problem definition for the current feature branch.

@shared-thoughts

Steps:
1. Detect branch and create `.thoughts/{BRANCH}/` if it doesn't exist
2. If `.thoughts/{BRANCH}/problem.md` exists, read it first
3. Based on the user's prompt, create/update `.thoughts/{BRANCH}/problem.md`
</TASK>

<SUCCESS_CRITERIA>
- `.thoughts/{BRANCH}` exists
- `.thoughts/{BRANCH}/problem.md` exists with the user's problem statement
- No other files or directories have been modified
</SUCCESS_CRITERIA>

<GUIDELINES>
- @read-only-specified-thoughts
- Keep the problem statement concise but complete
- This file is user-controlled - prioritize using their exact words
- Do not embellish or expand beyond what the user provides
</GUIDELINES>

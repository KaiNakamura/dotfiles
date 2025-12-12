<TASK>
Start a new iteration for the current feature branch.

@shared-thoughts

Steps:
1. Determine the branch and current iteration
2. If there are no previous iterations, create `iteration-01/` and skip to step 4
3. Otherwise, if there are previous iterations, find the current iteration (highest `.thoughts/{BRANCH}/iteration-NN/`)
   - Append a summary to `.thoughts/{BRANCH}/iterations.md` that captures the reason we need to reiterate. Our goal is to guide new agents so they don't repeat the same mistakes.
   - Create new iteration directory: `.thoughts/{BRANCH}/iteration-NN/` (next number)
4. Create `.thoughts/{BRANCH}/iteration-NN/progress.md` with a high level overview of the problem context
</TASK>

<SUCCESS_CRITERIA>
- `.thoughts/{BRANCH}/iterations.md` updated with summary of previous iteration (if any)
- New iteration directory created at `.thoughts/{BRANCH}/iteration-NN/`
- `.thoughts/{BRANCH}/iteration-NN/progress.md` created with context summary
- No other files or directories have been modified
</SUCCESS_CRITERIA>

<GUIDELINES>
- Our `iterations.md` and `progress.md` files should follow @summary-guidelines
</GUIDELINES>


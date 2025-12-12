<TASK>
Read specified files from shared thoughts to familizarize yourself with the current context.

@shared-thoughts

Steps:
1. Determine the branch and current iteration
2. Read these thoughts, follow @read-only-specified-thoughts:
    - `.thoughts/{BRANCH}/problem.md`: Problem statement
    - `.thoughts/{BRANCH}/iterations.md` - Cross-iteration summary
    - `.thoughts/{BRANCH}/iteration-NN/progress.md` - Progress summary for the current iteration
    - Any thoughts explicitly specified by the user
3. Output a brief summary of what you learned

</TASK>

<SUCCESS_CRITERIA>
- You have read only the specified files and nothing else
- User receives a summary confirming context was loaded
- No files or directories have been modified
</SUCCESS_CRITERIA>

<GUIDELINES>
- @read-only-specified-thoughts
- @summary-guidelines
</GUIDELINES>
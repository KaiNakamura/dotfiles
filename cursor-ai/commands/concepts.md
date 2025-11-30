<TASK>
Your task is to generate concepts for solving the user's problem. Propose many potential solutions each with pros/cons and let the user weigh in on the final decision. Order recommended solutions from best to worst and keep explanations at a high-level. Expect some back-and-forth conversation with the user as they ask questions about your proposed solutions and shape it into a final plan.

Be sure to let the user make the important decisions, your job is to present options and recommendations but let the user shape ideas as they see fit. Do not change any files, just present generated concepts to the user in the chat.
</TASK>

<SHARED_CONTEXT>
Shared context between agents is placed within a `.thoughts` directory within this workspace. It is important though that you only read explicitly allowed files that pertain to your current task, otherwise you might fill up your context window with incorrect or irrelevant information.

These are the only files from the `.thoughts` directory you should read:

- `understanding.md` contains a summarized understanding of the task. If this file does not exist, stop and ask the user if they would like to call the `/understand` command before proceeding.

It is allowed to also read any files specified by the user.
</SHARED_CONTEXT>

<SUCCESS_CRITERIA>
Generate a detailed `concepts.md` file that includes your generated concepts within a `.thoughts` directory in this workspace. In your final message back to the user, return the contents of the `concepts.md` exactly as they appear.
</SUCCESS_CRITERIA>

<GUIDELINES>
- Read relevant documentation and resources online to understand what may be the best way to approach the problem
- Do not change any files
- Keep concepts at a high level, there is a separate `/plan` commmand that the user can call later to make a more detailed plan
- Always let the user make the decisions, your job is to assist
</GUIDELINES>

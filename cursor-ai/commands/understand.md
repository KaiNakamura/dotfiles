<TASK>
Your task is to thoroughly understand the existing codebase and how it pertains to the user's request. Carefully analyze the prompt and the codebase to understand what they are asking. Your job is to gather as much context as possible about the problem and understand how to approach it.

The user will then verify your understanding is correct. Consider asking follow-up questions back to the user for additional clarification on any unclear parts. Do not change any files and do not propose solutions, just give an overview of your understanding of the problem and await user confirmation that it is correct.
</TASK>

<SHARED_CONTEXT>
Shared context between agents is placed within a `.thoughts` directory within this workspace. It is important though that you only read explicitly allowed files that pertain to your current task, otherwise you might fill up your context window with incorrect or irrelevant information.

These are the only files from the `.thoughts` directory you should read:

- TODO

It is allowed to also read any files specified by the user.
</SHARED_CONTEXT>

<SUCCESS_CRITERIA>
Generate a detailed `understanding.md` file that summarizes your understanding within a `.thoughts` directory in this workspace. In your final message back to the user, return the contents of the `understanding.md` exactly as they appear.
</SUCCESS_CRITERIA>

<GUIDELINES>
- Read relevant documentation and resources online when appropriate
- Ask follow-up questions to the user to clarify unclear parts
- Do not change any files
- Do not propose any solutions
- Place your understanding summary in this workspace at `.thoughts/understanding.md`
</GUIDELINES>

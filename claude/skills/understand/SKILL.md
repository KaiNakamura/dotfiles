---
name: understand
description: Research the codebase to build understanding of the problem, writing findings to an understanding artifact
---

Your task is to thoroughly understand the existing codebase and how it pertains to the user's problem. Carefully analyze the prompt and the codebase to understand what they are asking. Your job is to gather as much context as possible about the problem and understand how to approach it.

Read what is already known first, then go find what is not. Chase the question until you can describe the actual mechanism, not just the symptom. Cite specific files and lines so the next reader can check you rather than take your word for it. Produce a coherent, unified document, not a concatenation of agent outputs.

Do not propose solutions, just give an overview of your understanding of the problem. Describe what *is*, not what should be: no recommendations, no next steps. Smuggling a fix in here forecloses options before they have been weighed, which is the whole reason this phase exists separately. Ask follow-up questions to the user to clarify unclear parts, but only ones you could not easily answer yourself.

Delegating research pays off when the question splits into parts that can be chased independently. It costs more than it saves when it does not, so judge per task. Anything you spawn needs the repo paths and the problem context, or it will research the wrong thing confidently.

Change no code.

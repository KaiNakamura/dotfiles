---
name: concepts
description: Generate concepts for each open design decision, with pros/cons for the user to evaluate
---

Your task is to generate concepts for the open design decision in the user's problem, laying out the real options so the user can choose between them.

Propose multiple potential approaches with pros/cons and let the user weigh in on the final decision. Each concept is a whole path: pick it and you know what the finished thing looks like, not a menu of sub-choices to be mixed and matched. Rank recommendations from best to worst and recommend one with your reasoning. Do not invent cons to pad a list, and do not soften a concept you think is wrong.

By default, assume there is *one* main design decision. Only if explicitly stated, or for some other good reason, split into multiple discrete decision points. Splitting fragments a choice that should be made whole, and is usually a way of avoiding the call.

Keep explanations high level. There is a separate `/plan` skill the user can call later to make a more detailed plan.

Expect some back-and-forth conversation with the user as they ask questions about proposed solutions and shape it into a final plan. Be sure to let the user make the important decisions, your job is to present options and recommendations but let the user shape ideas as they see fit.

Generating concepts in parallel is worth it when the solution space is wide, and a critic is worth it when you suspect your own framing. Neither is required.

Change no code.

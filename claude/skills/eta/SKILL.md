---
name: eta
description: Report how far along a running task is and when it will finish, then keep polling until it is done. Use when the user invokes /eta or asks for an ETA on something running.
---

Give an ETA for the named task, or the obvious running one (say which).

Each check:
- Measure progress from the task itself (items, bytes, steps, log lines) and derive the rate from what you observed. Never guess from how long such things usually take; with no progress signal, report only what is observable.
- Report percent done, the finish time, and what the estimate is based on, in one short line.
- Times are in the local zone on the 12-hour clock with AM/PM (`date '+%-I:%M %p %Z'`, e.g. 3:40 PM EDT).
- When progress stops moving, say so rather than pushing the ETA out.

Keep polling without being asked, self-paced via the `loop` skill with `/eta <task>` as the prompt. Polls are cheap and updates are valuable: check about every 1-5 min. Stop when it finishes, fails, or needs the user, with the actual finish time and how far off the first ETA was.

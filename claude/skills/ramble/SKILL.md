---
name: ramble
description: Work recorded talk-to-script takes into a video script note in Obsidian. Use when the user invokes /ramble, or asks to turn their recorded rambles or takes into the script.
---

talk-to-script records Kai rambling a video script out loud and splits it into transcribed takes. The script itself is a markdown note in the notes vault. This skill places the good takes into that note. The note stays Kai's document: he reads and edits it in Obsidian.

## Find the takes

- The server writes its URL to `~/talk-to-script/server.json` (or `$TALK_TO_SCRIPT_DIR/server.json`). If it is missing or not answering, tell Kai to run `task talk-to-script:serve` in `~/repos/homelab-apps` and stop
- `GET {url}/api/projects` lists projects, each with a `note_path`. Use the one Kai names, otherwise the most recent, and say which
- `GET {url}/api/projects/{id}/takes.md?unplaced=1` lists the takes not yet in the note, retakes grouped together. Drop `?unplaced=1` to see everything
- Read the note at `note_path` in full

## Decide

- One take per group: starred wins, rejected never goes in, otherwise the fewest fillers, and the latest on a tie
- Takes marked "note to self" are Kai talking to you ("put this before the Quick Draw bit", "those last takes were good"). Follow them, never put them in the script
- Place each line under the heading it talks about, in the order that reads best. Say which lines are transitions, which fit nowhere, and which headings still have nothing
- If the note has no structure yet, propose headings from what Kai said

## Propose, then edit

- Show the plan compactly: heading, then the lines going under it with their take ids. Wait for Kai's go-ahead or changes
- Each spoken line goes on its own line as `{text} %%take:{id}%%`. The `%%` comment is hidden in Obsidian's reading view and ties the line to its audio
- Put spoken lines after the outline lines already under a heading. Never delete or rewrite Kai's own lines
- Light cleanup only (drop "um", fix punctuation). The audio is what he said, so keep the wording
- To swap in a better retake, change the id and the text together. To reorder, move whole lines
- Afterwards, `GET {url}/api/projects/{id}/note` gives the length of the placed audio. Report it against the project's `target_seconds`
- Don't commit the notes repo unless asked

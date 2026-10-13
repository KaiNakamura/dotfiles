---
name: sync
description: Sync the thoughts vault and in-progress repos between this machine and a remote session, such as a Coder workspace, so both have the same context and code. Use when the user invokes /sync or wants a remote session brought up to date.
---

Bring both machines to the same commit for the thoughts vault and every repo with work the other side needs. Git is the only transport.

## What to sync

- The thoughts vault, always.
- Repos the current session touched, and repos named in the current node's `repo:` frontmatter.
- Skip anything already in sync on both sides.

## How

For each repo, on each machine in turn: commit pending work, pull with rebase, push. Then pull once more on the machine that went first, so both end on the same commit. Reach the remote machine over ssh.

- Vault commits go to its main branch. Repo work goes to its own branch, never main.
- Never force-push, and never discard or stash away uncommitted work.
- On a conflict or diverged history, stop that repo and report it; keep syncing the rest.

## Report

One line per repo: what moved in which direction, or why it was skipped.

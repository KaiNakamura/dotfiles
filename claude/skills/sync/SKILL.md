---
name: sync
description: Sync context and code between this machine and one or more other workspaces so work can continue on any of them. Use when the user invokes /sync or is about to hand work to another machine.
---

Sync this machine with the workspaces the user names, so each has the same context and code and is ready to continue the work. Git is the transport.

## What to sync

- The thoughts vault.
- The repos the work in progress depends on.

## Rules

- Never force-push, and never discard uncommitted work.
- On a conflict, stop that repo and report it; keep syncing the rest.

## Report

One line per repo and workspace: what moved, or why it was skipped.

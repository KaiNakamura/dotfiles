---
name: sync
description: Sync context and code between this machine and one or more other machines so work can continue on any of them. Use when the user invokes /sync or is about to hand work to another machine.
---

Sync this machine with the other machines the user names, so each has the same context and code and is ready to continue the work. Git is the transport.

## What to sync

- The thoughts vault.
- The repos the work in progress depends on.

## Rules

- Sync only the machines this one can reach. Push this machine's work so an unreachable machine can pull it later.
- Never force-push, and never discard uncommitted work.
- Resolve conflicts, keeping both sides' work. Ask the user only when the two sides cannot both be kept.

## Report

One line per repo and machine: what moved, or why it was skipped.

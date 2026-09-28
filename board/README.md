# board

A kanban board over the thoughts vault.

```
board serve      # http://127.0.0.1:8788, opens a browser
board list       # the same board in the terminal
board open [node]  # a node's page, else the one you stand in (alias thb)
board mv <node> <status>
```

The vault already records every piece of work and what state it is in, so the
board keeps no store of its own. Cards are vault nodes, the columns are the
vault's seven statuses, and dragging a card rewrites that node's `status:` and
nothing else. There is one copy of the truth and nothing to sync.

Nodes and running agents both come from `th`:

- `th status --all --json` is the card feed -- slug, status, description, repos,
  links, and where each node sits in the tree.
- `th agents --json` says which nodes have an agent in them right now, so a card
  pulses while work is moving and dims once it goes quiet.

## What is on the board

Everything not resolved. `done` and `canceled` are hidden behind **show
resolved** (`a`), along with nodes that declare no status at all -- those are
the unconverted heads, and dragging one out of the *no status* column is how it
gets a status for the first time.

A status outside the vocabulary gets its own column rather than being coerced
or hidden, so a typo is visible instead of silent.

## Notes

- The board writes into a git repo you commit by hand. A day of dragging cards
  is a day of one-line diffs to `status:` keys, which is the intended trade:
  the board moves real state, not a copy of it.
- The write is line-based on purpose. A YAML round trip would reformat the
  whole frontmatter block -- quoting, key order, the `repos:` mapping -- and
  every head file is hand-written.
- Requires Python 3.8+ and `th`. Nothing else.

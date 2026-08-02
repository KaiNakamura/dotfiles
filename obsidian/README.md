# obsidian

Headless Obsidian CLI in a long-running Docker container, based on
[obsidianless](https://github.com/lucastraba/obsidianless). Lets
`obsidian orphans total` / `obsidian unresolved total` (the
`vault-health` rule in `~/.claude/rules/`) work on a Coder box that has
no display.

## Depends on

- `docker/` module (must come before this in `INSTALL_ORDER_CODER`).

## What it installs

- Image `obsidianless` built locally from this directory's `Dockerfile`,
  pinned to `OBSIDIAN_VERSION` (top of `install.sh`).
- Container `obsidian`, `--restart unless-stopped`. The vault's parent
  directory (e.g. `~/repos/`) is bind-mounted at `/vault/`, so the
  vault lives at `/vault/<basename>` inside the container. Parent-mount
  rather than leaf-mount means the vault can be cloned after install
  and appear live in the container without restart. Config dir at
  `/home/obsidian/.config/obsidian`.
- Wrapper `~/.local/bin/obsidian` that proxies to `docker exec` into the
  long-running container, plus an `obsidian-cli` symlink to the same
  wrapper.

## Gotcha: stale command hash

Shells cache command paths on first use. If you installed from a shell
that had already run the native `obsidian`, that shell keeps resolving
to `/usr/bin/obsidian` and you get the GUI app's complaints instead of
the CLI:

```
Your Obsidian installer is out of date. ...
Command line interface is not enabled. Please turn it on in Settings > General > Advanced.
```

Fix: `hash -r`, or open a new shell. Confirm with `type obsidian` ->
should be `~/.local/bin/obsidian`.

## Gotcha: desktop machines

This module is Coder-only (it is in `INSTALL_ORDER_CODER`, not
`INSTALL_ORDER`). If you install it by hand on a desktop that has the
native app, `~/.local/bin/obsidian` shadows `/usr/bin/obsidian` for all
terminal invocations. Use `obsidian-cli` for the container CLI and
`/usr/bin/obsidian` to launch the GUI. The installer prints a warning
when it detects a native binary.

## Why `sudo docker` during install

The `docker/` module does `usermod -aG docker $USER` but the new group
isn't active in the current shell (supplementary groups are read at
login). Rather than re-exec the orchestrator under `sg` or force the
user to logout/login mid-install, every install-time docker call here
uses `sudo docker`. The socket is `root:docker 0660` -> sudo bypasses
the group entirely. **Don't "fix" this to plain `docker`** unless you've
also changed how the orchestrator handles group activation.

The user-facing wrapper uses plain `docker exec` because by the time
the user invokes it interactively they have a fresh login shell with
the group active.

## Configuration (env vars)

- `OBSIDIAN_VAULT_HOST` (default `$HOME/repos/thoughts`)
- `OBSIDIAN_VAULT_NAME` (default `thoughts`)
- `OBSIDIAN_CONTAINER_NAME` (default `obsidian`)
- `OBSIDIAN_IMAGE_NAME` (default `obsidianless`)

## Version bumps

Edit `OBSIDIAN_VERSION` in `install.sh`. The Dockerfile takes it via
`--build-arg`. The pinned AppImage URL templates against the version.

Auto-update is mitigated by pinning + `--restart unless-stopped` (no
opportunity for the in-container Obsidian to fetch a newer asar that
would mismatch the main process). A future `obsidian.json` update-off
key, if one exists, would belt-and-suspenders this.

## Profile

Coder only. Desktop machines have the GUI Obsidian app and don't need
this.

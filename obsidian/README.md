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
- Container `obsidian`, `--restart unless-stopped`, vault bind-mounted
  at `/vault/$VAULT_NAME`, config dir at `/home/obsidian/.config/obsidian`.
- Wrapper `~/.local/bin/obsidian` that proxies to `docker exec` into the
  long-running container.

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

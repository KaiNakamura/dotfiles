#!/bin/bash
# obsidian module: builds + runs an obsidianless-based Docker container
# so the Obsidian CLI (`obsidian orphans total`, etc.) works on a headless
# Coder box without a display. Upstream: https://github.com/lucastraba/obsidianless
#
# Depends on the `docker/` module being installed first.
#
# Why `sudo docker` during install: the docker/ module does `usermod -aG
# docker` but the new group isn't active in the current shell (supplementary
# groups are read at login). Rather than re-exec under `sg` or punt the user
# to relogin, every install-time docker call uses `sudo docker`. The socket
# is root:docker 0660 -> sudo bypasses the group entirely. The user-facing
# wrapper at ~/.local/bin/obsidian uses plain `docker exec` since by the
# time it's invoked interactively the user has relogged.

set -e

OBSIDIAN_VERSION="1.12.7"

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_HOST="${OBSIDIAN_VAULT_HOST:-$HOME/repos/thoughts}"
VAULT_NAME="${OBSIDIAN_VAULT_NAME:-thoughts}"
# Mount the parent of the vault rather than the vault itself. The vault is
# cloned interactively after install (private repo, see iter-07), so binding
# the leaf path at install time auto-creates an empty root-owned dir and
# shadows the later clone. Parent is pre-created here and the vault appears
# live inside the container the moment the user runs `gh repo clone ...`.
VAULT_PARENT="$(dirname "$VAULT_HOST")"
VAULT_BASENAME="$(basename "$VAULT_HOST")"
CONTAINER_NAME="${OBSIDIAN_CONTAINER_NAME:-obsidian}"
IMAGE_NAME="${OBSIDIAN_IMAGE_NAME:-obsidianless}"
CONFIG_DIR="$HOME/.config/obsidianless"

if ! command -v docker >/dev/null 2>&1; then
    echo "obsidian: ERROR - docker not found; the docker/ module must run first" >&2
    exit 1
fi

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
echo "obsidian: building $IMAGE_NAME (version=$OBSIDIAN_VERSION uid=$HOST_UID gid=$HOST_GID)"
sudo docker build \
    --build-arg "OBSIDIAN_VERSION=$OBSIDIAN_VERSION" \
    --build-arg "OBSIDIAN_UID=$HOST_UID" \
    --build-arg "OBSIDIAN_GID=$HOST_GID" \
    -t "$IMAGE_NAME" \
    "$MODULE_DIR"

# Seed config dir with vault entry + cli toggle. Vault path inside the
# container resolves through the parent bind mount: /vault/<basename>.
# Always (re)write so re-runs pick up path changes (e.g. mount-strategy
# migration from /vault/$VAULT_NAME to /vault/$VAULT_BASENAME).
mkdir -p "$CONFIG_DIR"
cat >"$CONFIG_DIR/obsidian.json" <<EOF
{
  "vaults": {
    "$VAULT_NAME": {
      "path": "/vault/$VAULT_BASENAME",
      "ts": 1710000000000,
      "open": true
    }
  },
  "cli": true
}
EOF

# (Re)start the container.
if sudo docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    sudo docker rm -f "$CONTAINER_NAME" >/dev/null
fi

# Pre-create the parent so the bind mount resolves to a real inode. The
# vault leaf may or may not exist yet; if absent, it'll appear live when
# the user clones it.
mkdir -p "$VAULT_PARENT"
if [[ ! -d "$VAULT_HOST" ]]; then
    echo "obsidian: vault $VAULT_HOST not yet present; will appear in container once cloned"
fi

echo "obsidian: starting $CONTAINER_NAME"
sudo docker run -d \
    --restart unless-stopped \
    --name "$CONTAINER_NAME" \
    -e "OBSIDIAN_VAULT_PATH=/vault/$VAULT_BASENAME" \
    -v "$VAULT_PARENT:/vault" \
    -v "$CONFIG_DIR:/home/obsidian/.config/obsidian" \
    "$IMAGE_NAME" >/dev/null

# Install user-facing wrapper. Plain `docker exec` (no sudo, no sg).
# Users invoke this in a post-relogin shell where the docker group is active.
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/obsidian" <<'WRAPPER'
#!/usr/bin/env bash
# obsidianless wrapper: run Obsidian CLI inside the long-running `obsidian`
# container. Plain `docker exec` works once the user has relogged after
# the docker module added them to the docker group. If the current shell
# pre-dates the group change, fall back to `sg docker -c` so the wrapper
# is usable from same-session callers (e.g., Claude Code's vault-health
# hook firing inside the install shell).
#
# Self-heal: if the call returns "Vault not found" (Obsidian process opened
# its config before the vault directory existed and didn't auto-rescan),
# restart the container and retry once. Belt-and-suspenders alongside the
# entrypoint vault-wait, mostly for legacy containers that started under
# the old entrypoint.
CONTAINER_NAME="${OBSIDIAN_CONTAINER_NAME:-obsidian}"

run_in_container() {
    if docker info >/dev/null 2>&1; then
        docker exec -e DISPLAY=:99 "$CONTAINER_NAME" /opt/obsidian/obsidian --no-sandbox "$@" \
            2> >(grep -v "ERROR:dbus/bus.cc" >&2)
    elif id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker \
         || getent group docker 2>/dev/null | grep -qw "$USER"; then
        sg docker -c "docker exec -e DISPLAY=:99 $CONTAINER_NAME /opt/obsidian/obsidian --no-sandbox$(printf ' %q' "$@")" \
            2> >(grep -v "ERROR:dbus/bus.cc" >&2)
    else
        echo "obsidian: ERROR - $USER not in docker group; install docker module first" >&2
        return 1
    fi
}

restart_container() {
    if docker info >/dev/null 2>&1; then
        docker restart "$CONTAINER_NAME" >/dev/null
    else
        sudo docker restart "$CONTAINER_NAME" >/dev/null
    fi
}

OUT=$(run_in_container "$@" 2>&1)
RC=$?
if [[ "$OUT" == *"Vault not found"* ]]; then
    echo "obsidian: vault not loaded; restarting container and retrying" >&2
    restart_container
    sleep 2
    OUT=$(run_in_container "$@" 2>&1)
    RC=$?
fi
printf '%s\n' "$OUT"
exit "$RC"
WRAPPER
chmod +x "$HOME/.local/bin/obsidian"

# Wait for container to be Up. Don't probe via `docker exec obsidian
# version`: with cli:true in obsidian.json, that subcommand causes the
# long-running Obsidian process to exit, putting the container into a
# restart loop. We rely on `--restart unless-stopped` + container-state
# check; first wrapper invocation will trigger the natural restart cycle
# if needed. Vault indexing happens lazily inside the container.
echo -n "obsidian: waiting for container to be Up"
for _ in $(seq 1 30); do
    state=$(sudo docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "missing")
    if [[ "$state" == "running" ]]; then
        echo
        echo "obsidian: container running (image=$IMAGE_NAME, version=$OBSIDIAN_VERSION)"
        echo "obsidian: invoke via ~/.local/bin/obsidian (e.g., obsidian orphans total)"
        exit 0
    fi
    echo -n "."
    sleep 1
done
echo
echo "obsidian: WARNING - container not running after 30s; check 'sudo docker logs $CONTAINER_NAME'"
exit 0

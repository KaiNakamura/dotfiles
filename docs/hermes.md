# Hermes spoke

The `hermes` module turns a machine into a spoke of the Hermes hub, which runs on the homelab k8s and hosts all 12 bots.

## Why spokes have no bots

- The hub is the single source of truth for every bot, along with its memory, routines, and connectors.
- A spoke runs only the default agent, which acts as the machine's hands: terminal, local repos, and Claude Code.
- Nothing is imported on a spoke, so routines are never duplicated. The Grok importer is never run.

## Install

```sh
HERMES_HUB_KEY=... ./install.sh hermes
```

- Installs Hermes with the official script (`--non-interactive`).
- Writes these settings to `~/.hermes/.env` (chmod 600): `API_SERVER_ENABLED=true`, `API_SERVER_HOST=0.0.0.0`, `API_SERVER_PORT=8642`, and an `API_SERVER_KEY` that is generated once.
- Sets the timezone to `America/New_York` and writes a one-line `SOUL.md` role.
- Runs the gateway with the systemd user unit `hermes-spoke.service`. Coder has no systemd, so `start_hermes = true` starts it at install instead (`ensure_hermes_gateway`, the same approach as `start_tailscale`).
- Hermes still needs a model provider. Configure it once with `hermes setup` or `hermes config set`.

## Peering (both ways)

- On the spoke: `HERMES_HUB_KEY=... hermes-spoke peer-hub` adds the peer `hub`.
- On the hub: run the line printed by `hermes-spoke hub-cmd`.
- After that, `message_agent(target="hub")` works from the spoke, and `target="<hostname>"` works from the hub.

## Hub URL per profile

`hermes/hub.<profile>.env` is resolved with `resolve_asset`:

- `home` (the default `hub.env`): `http://hermes-api.pufferfish-cod.ts.net:8642` on the personal tailnet. This host is being added in a separate homelab PR.
- `work` and `coder`: `http://kai-hermes-hub:8642` on the work tailnet.

## kai-g727

The old trial `~/.hermes` is moved to `~/.hermes.trial-bak`. This happens once: it is skipped if `~/.hermes/.spoke` or the backup already exists.

## Secrets

- Keys are never committed.
- The spoke key exists only in `~/.hermes/.env` and is printed only by `hermes-spoke key` or `hermes-spoke hub-cmd`.
- The hub key comes from `HERMES_HUB_KEY` at install time.

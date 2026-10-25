# Tailscale

The `tailscale` module installs Tailscale. On boxes without systemd (`start_tailscale = true`), `ensure_tailscaled` starts the daemon in nftables mode (Debian's iptables-nft lacks connmark).

Bash and zsh alias `ts` to `tailscale`.

## Add tailnets

```sh
TS_AUTHKEY_PERSONAL=tskey-auth-... ./tailscale/install.sh
```

- Adds profiles nicknamed `personal` and `work` (`TS_AUTHKEY_WORK`); existing ones are skipped. Never commit keys.
- `work` is admin-gated: needs an admin-issued key and IT sign-off. Optional.

## Switch

- Active tailnet: `tailscale switch --list` (marked `*`)
- Switch: `tailscale switch personal` or `tailscale switch work`
- Default to `personal`; switch back after work tasks.

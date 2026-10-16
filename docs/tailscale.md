# Tailscale

The `tailscale` module installs Tailscale. On boxes without systemd
(`start_tailscale = true`, e.g. the grok profile) `ensure_tailscaled` starts
`tailscaled` from the shell rc, using kernel tun when `/dev/net/tun` exists
and userspace networking otherwise.

Each tailnet is a separate Tailscale profile, nicknamed `personal` and `work`.
Only one is connected at a time. `personal` is the default; `work` is optional.

`tailscaled` runs with `TS_DEBUG_FIREWALL_MODE=nftables`: Debian's iptables-nft
shim lacks connmark and trips a health warning otherwise.

## Adding the tailnets

Export auth keys (never commit them), then rerun the module:

```sh
TS_AUTHKEY_PERSONAL=tskey-auth-... TS_AUTHKEY_WORK=tskey-auth-... ./tailscale/install.sh
```

Profiles that already exist are skipped. The operator is set after login so
`tailscale switch --list` works without sudo.

`work` is admin-gated: it needs an admin-issued tagged key (or admin approval of
`tailscale login`) and IT sign-off before a non-Cyvl-managed box joins the work
network. Skip it until both are in place. `TS_HOSTNAME` overrides the node name.
Desktops can instead run `tailscale login --nickname=personal` interactively.

## For agents: check and switch

- Which tailnet is active: `tailscale switch --list` (active row has `*`) or `tailscale status`.
- If `switch --list` says access denied: `sudo tailscale set --operator=$USER`.
- Switch: `tailscale switch work` or `tailscale switch personal`. Existing connections drop; peers and MagicDNS names change with it.
- Use `personal` for homelab and Home Assistant, `work` (if present) only for work tasks. Switch back to `personal` when done.
- If `tailscale status` cannot reach the daemon, run `ensure_tailscaled` (from `lib/shell_rc.sh`).

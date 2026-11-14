# WSL

Ubuntu WSL on kai-g727's Windows boot (`kai-desktop`, tailnet `kai-g727-wsl`).

## Keepalive

WSL stops soon after the last Windows-side `wsl.exe` exits; Linux-side processes don't count. `./wsl/install.sh` (inside WSL, no admin) registers and starts the hidden logon task `WSL-Keepalive`.

- Check: `schtasks /query /tn WSL-Keepalive`
- Remove: `Unregister-ScheduledTask WSL-Keepalive -Confirm:$false`

## Done by hand

- `/etc/wsl.conf`: `[boot] systemd=true`, then `wsl --shutdown` once
- `sudo apt install -y openssh-server && sudo systemctl enable --now ssh`; Hermes pod key (`hermes/hub_ssh.pub`) in `~/.ssh/authorized_keys`
- `sudo tailscale up --hostname=kai-g727-wsl --ssh=false` (Tailscale SSH would bypass `authorized_keys`)
- `loginctl enable-linger kai` so user units start at boot
- No sudo, so node is a user-level tarball in `~/.local/opt/node`. It needs `libatomic.so.1`, unpacked from `apt-get download libatomic1` into `~/.local/opt/libatomic` and set via `LD_LIBRARY_PATH` in a `~/.local/bin/node` wrapper. pnpm: `npm i -g --prefix ~/.local pnpm`

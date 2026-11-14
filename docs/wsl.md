# WSL

Notes for the Ubuntu 24.04 WSL distro on kai-g727's Windows boot (`kai-desktop`, tailnet `kai-g727-wsl`). Most of this was done by hand; only the keepalive is scripted.

## Keepalive (scripted)

WSL stops the distro shortly after the last Windows-side `wsl.exe` exits. Linux-side processes (sshd, systemd user units, ssh sessions, linger) don't count, so without an open Ubuntu window the pod loses ssh and `localhost:<port>` apps go away.

```sh
./wsl/install.sh            # from inside WSL; or -Distro <name>
```

- Registers the per-user Scheduled Task `WSL-Keepalive` (at logon, no admin) and starts it.
- It runs `conhost.exe --headless wsl.exe --exec /bin/sleep infinity`. `--headless` means no console window ever shows.
- No time limit, runs on battery, one instance at a time.
- To run it from Windows instead: `powershell -ExecutionPolicy Bypass -File wsl\keepalive.ps1 -Start`
- To check it: `schtasks /query /tn WSL-Keepalive`. To remove it: `Unregister-ScheduledTask WSL-Keepalive -Confirm:$false`
- `.wslconfig` isn't changed. `vmIdleTimeout` only covers the VM after the distro has stopped, so it doesn't help here.

## Done by hand

- `/etc/wsl.conf`: `[boot] systemd=true`, `[user] default=kai`, then `wsl --shutdown` once.
- `sudo apt install -y openssh-server && sudo systemctl enable --now ssh`. The Hermes pod key (`hermes/hub_ssh.pub`, comment `hermes-pod`) is in `~/.ssh/authorized_keys`.
- `sudo tailscale up --hostname=kai-g727-wsl --ssh=false`. Keep `--ssh=false`, because Tailscale SSH bypasses `authorized_keys`.
- `loginctl enable-linger kai`, so user units start at boot.
- sudo needs a password, so the toolchain is user-level:
  - Node is an LTS tarball in `~/.local/opt/node-<v>-linux-x64`, symlinked to `~/.local/opt/node`.
  - `libatomic.so.1` is missing, so it was extracted without root: `apt-get download libatomic1 && dpkg -x libatomic1_*.deb ~/.local/opt/libatomic`.
  - `~/.local/bin/node` is a wrapper:
    ```sh
    #!/bin/sh
    export LD_LIBRARY_PATH=$HOME/.local/opt/libatomic/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    exec $HOME/.local/opt/node/bin/node "$@"
    ```
  - pnpm: `npm i -g --prefix ~/.local pnpm@<version>`
- Clip Farm camera editor at http://localhost:3310 is the user unit `~/.config/systemd/user/clip-farm-editor.service`, enabled with `systemctl --user enable --now clip-farm-editor`:
  ```ini
  [Unit]
  Description=Clip Farm camera editor (localhost:3310)

  [Service]
  WorkingDirectory=%h/repos/homelab-apps
  Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
  Environment=CAMERA_EDITOR_MEDIA_ROOTS=/home/kai:/home/kai/repos/homelab-apps/apps/clip-farm/remotion:/mnt/c/Users/kai/Videos
  ExecStart=%h/.local/bin/pnpm -C apps/clip-farm/remotion editor --host 127.0.0.1 --port 3310 --strictPort
  Restart=on-failure

  [Install]
  WantedBy=default.target
  ```

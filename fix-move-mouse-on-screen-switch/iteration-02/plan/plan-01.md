# Plan: Create ydotool Package and Integrate into Dotfiles Installation

## Context

Based on `understanding-02.md`, we need to:
1. Install `ydotool` package via apt
2. Set up `ydotoold` daemon as a system-wide service (root)
3. Configure permissions for `/dev/uinput` access
4. Ensure daemon starts automatically on boot
5. Integrate this setup into the dotfiles installation flow, running **right before KDE setup**

## User Requirements

- **Separate package**: Create a new `ydotool/` directory in dotfiles
- **Installation method**: Use `apt install` (package manager)
- **Service type**: System-wide service (root) is acceptable
- **Installation order**: Install ydotool right before KDE setup in `install.sh`

## Current State

- **Main install script**: `/home/kai/repos/dotfiles/install.sh`
- **KDE install script**: `/home/kai/repos/dotfiles/kde/install.sh`
- **Install order**: Currently KDE is installed at position 7 in `INSTALL_ORDER` array
- **ydotool status**: Already installed at `/usr/bin/ydotool` (from previous iteration)
- **Daemon status**: Not running (blocker)
- **Permissions**: User not in `input` group, `/dev/uinput` access denied

## Implementation Plan

### Phase 1: Create ydotool Package Structure

**Task 1.1**: Create `ydotool/` directory
- Location: `/home/kai/repos/dotfiles/ydotool/`
- Create directory structure similar to other packages (e.g., `wayland/`, `bat/`)

**Task 1.2**: Create `ydotool/install.sh` script
- Follow pattern from other install scripts (e.g., `wayland/install.sh`)
- Script should install via apt: `sudo apt update && sudo apt install -y ydotool`

**Task 1.3**: Create service file in package
- Create `ydotool/ydotoold.service` file in the package directory
- Service file content:
  ```ini
  [Unit]
  Description=ydotool daemon
  After=graphical.target

  [Service]
  Type=simple
  ExecStart=/usr/bin/ydotoold
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
  ```

**Task 1.4**: Set up systemd service (system-wide)
- Copy service file from package to `/etc/systemd/system/ydotoold.service`
- Use: `sudo cp ydotool/ydotoold.service /etc/systemd/system/ydotoold.service`

**Task 1.5**: Configure permissions
- Add user to `input` group: `sudo usermod -aG input $USER`
- Note: Group membership requires logout/login to take effect
- Provide clear message to user about logout/login requirement

**Task 1.6**: Enable and start service
- Reload systemd: `sudo systemctl daemon-reload`
- Enable service: `sudo systemctl enable ydotoold`
- Start service: `sudo systemctl start ydotoold`
- Verify service is running: `sudo systemctl status ydotoold`

**Task 1.7**: Verification
- Check daemon is running: `systemctl is-active ydotoold` or `ps aux | grep ydotoold`
- Test ydotool functionality: `ydotool mousemove --absolute -x 100 -y 100`
- Provide clear success/failure messages

### Phase 2: Integrate into Main Installation Flow

**Task 2.1**: Update `install.sh` INSTALL_ORDER array
- Add `"ydotool"` to `INSTALL_ORDER` array
- Position: Right before `"kde"` (currently at index 7)
- New order should be: `..., "zoxide", "kitty", "nvim", "vim", "ydotool", "kde", ...`

**Task 2.2**: Verify integration
- Ensure `ydotool` module directory exists before installation
- Ensure `ydotool/install.sh` is executable
- Test that installation flow works: `./install.sh ydotool kde`

### Phase 3: Testing and Verification

**Task 3.1**: Test standalone installation
- Run `./ydotool/install.sh` directly
- Verify all steps complete successfully
- Verify daemon starts and ydotool works

**Task 3.2**: Test integrated installation
- Run `./install.sh ydotool kde` to test installation order
- Verify ydotool installs before KDE
- Verify KDE scripts can use ydotool after installation


## Implementation Details

### ydotool/install.sh Structure

```bash
#!/bin/bash

# Exit on error
set -e

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install ydotool package
sudo apt update
sudo apt install -y ydotool

# 2. Add user to input group
echo "Adding user to input group..."
sudo usermod -aG input "$USER"
echo "Please log out and back in for group changes to take effect"

# 3. Copy service file
sudo cp "$WORKDIR/ydotoold.service" /etc/systemd/system/

# 4. Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable ydotoold
sudo systemctl start ydotoold

echo "ydotoold daemon started"
```

## Open Questions

1. **Service name**: Is it `ydotoold.service` or `ydotool.service`?
   - Need to verify actual package contents
   - Plan assumes `ydotoold.service` based on understanding doc

2. **Service file location**: Does the apt package include a systemd service file?
   - Plan uses our own service file from the package directory
   - Can verify package contents: `dpkg -L ydotool | grep service`

3. **Group membership timing**: Should we warn about logout/login requirement?
   - Plan includes warning message

4. **Dependencies**: Does ydotool have any dependencies?
   - `apt install` should handle dependencies automatically
   - May need to verify on clean system

## Success Criteria

- [ ] `ydotool/` directory created with `install.sh` script
- [ ] `ydotool/ydotoold.service` file created
- [ ] `ydotool` package installs via apt
- [ ] User added to `input` group (with warning about logout/login)
- [ ] Systemd service file copied and configured
- [ ] Service enabled and started automatically
- [ ] Service verified running after installation
- [ ] `ydotool` command tested and working
- [ ] Integration into `install.sh` complete (ydotool before kde)

## Next Steps After This Plan

1. **Implement ydotool package** (Phase 1)
2. **Integrate into installation flow** (Phase 2)
3. **Test and verify** (Phase 3)
4. **Update KDE scripts** to use ydotool (future iteration)
5. **Remove xdotool dependency** from `apply-scripts.sh` (future iteration)

## Notes

- This plan focuses on setting up `ydotool` infrastructure
- Actual script modifications to use `ydotool` instead of `xdotool` will be in a future iteration
- The installation order ensures `ydotool` is available before KDE scripts are configured
- System-wide service is acceptable per user requirements (root install is fine)


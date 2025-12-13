# Progress: Iteration 05

## Problem Context

KDE scripts for mouse cursor movement (used with keybinds like Meta+HJKL and Meta+Shift+HJKL) no longer work after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh` - centers cursor on active window

**Current Implementation** (X11):
- Uses `xdotool getactivewindow` to get window ID
- Uses `xdotool getwindowgeometry` to get window position/size
- Uses `xdotool mousemove` to move cursor

## Previous Iteration Summary

**Iteration 01** attempted to implement ydotool integration but was blocked at Phase 1.2 verification:
- `ydotool` is installed but `ydotoold` daemon not running
- Permission issues with `/dev/uinput` access
- Verification cannot proceed without daemon setup

**Iteration 02** completed the installation infrastructure:
- Created `ydotool/` package with installation script
- Set up systemd service for `ydotoold` daemon
- Integrated into main dotfiles installation flow

**Iteration 03** fixed installation script bug:
- Discovered install script was missing `ydotoold` package installation
- Fixed `ydotool/install.sh` to install both `ydotool` and `ydotoold` packages

**Iteration 04** implemented enhanced systemd service configuration:
- Updated service file with `Restart=always`, better dependencies, and logging
- Added uinput module loading configuration
- Service configuration contains unsupported key (`StartLimitIntervalSec`) causing systemd error
- Service remains inactive (dead) after reboot despite being enabled

## Current Issue

After implementing Option 1 from concepts-02.md (Enhanced Systemd Service), the user installed the updated configuration and restarted. Two problems identified:

1. **Systemd compatibility issue**: Service file contains `StartLimitIntervalSec=0` which is not recognized by the systemd version:
   ```
   Unknown key name 'StartLimitIntervalSec' in section 'Service', ignoring.
   ```
   This suggests the systemd version may be older than 230 (when this key was added).

2. **Service not starting**: Service status shows:
   ```
   Active: inactive (dead)
   ```
   The service is enabled but not active after reboot. This could be due to:
   - Configuration error preventing service from loading properly
   - Dependency issues (graphical.target not available when service tries to start)
   - Permission or execution environment problems
   - Service failing to start and not restarting due to configuration error

## Current Iteration Goals

1. **Fix systemd compatibility**: Remove or replace `StartLimitIntervalSec` key to work with current systemd version
2. **Investigate service startup failure**: Check service logs to understand why it's not starting
3. **Verify service can start manually**: Test if service starts when run manually after fixing configuration
4. **Resolve dependency issues**: Ensure service starts at correct time in boot sequence
5. **Verify persistence**: Ensure service starts reliably after reboot with fixed configuration

## Next Steps

- Check systemd version: `systemctl --version` to determine compatibility
- Remove or conditionally use `StartLimitIntervalSec` based on systemd version
- Check service logs: `journalctl -u ydotoold -n 100` to see why service isn't starting
- Verify service file loads correctly: `systemctl daemon-reload` and check for errors
- Test manual start: `sudo systemctl start ydotoold` after fixing configuration
- Verify dependencies: Check if `graphical.target` and `systemd-modules-load.service` are available
- Once service starts, verify it persists after reboot



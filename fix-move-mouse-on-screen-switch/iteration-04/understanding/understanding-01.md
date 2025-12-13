# Understanding: Iteration 04

## Problem Context

The user has KDE scripts that move the mouse cursor when using keyboard shortcuts (Meta+HJKL for window switching, Meta+Shift+HJKL for moving windows between screens). These scripts stopped working after switching from X11 to Wayland because they rely on `xdotool`, which is X11-specific and doesn't work on Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh` - centers the cursor on the active window after window operations.

**Current Implementation** (X11-based):
- Uses `xdotool getactivewindow` to get the active window ID
- Uses `xdotool getwindowgeometry` to get window position and size
- Uses `xdotool mousemove` to move the cursor to the center of the window

## Solution Approach

The solution is to replace `xdotool` with `ydotool`, which is a Wayland-compatible tool for simulating input events. However, `ydotool` requires a daemon (`ydotoold`) to be running to function.

## Previous Iteration Progress

**Iteration 01**: Attempted to implement ydotool integration but was blocked because:
- `ydotoold` daemon was not running
- Permission issues with `/dev/uinput` access
- User not in `input` group

**Iteration 02**: Created installation infrastructure:
- Created `ydotool/` package directory following dotfiles patterns
- Created `ydotool/install.sh` that installs ydotool, adds user to `input` group, and sets up systemd service
- Created `ydotool/ydotoold.service` systemd service file
- Integrated into main `install.sh` before KDE setup

**Iteration 03**: Fixed installation script bug:
- Discovered that `ydotool` and `ydotoold` are separate packages
- Fixed `ydotool/install.sh` to install both packages: `sudo apt install -y ydotool ydotoold`
- Installation script now properly installs both CLI tool and daemon

## Current Issue (Iteration 04)

The user has executed `./install.sh ydotool` (with the fixed script from iteration 03) and restarted their computer, but the `ydotoold` service is not running after reboot.

**Installation Script Actions** (`ydotool/install.sh`):
1. Installs both `ydotool` and `ydotoold` packages via apt
2. Adds user to `input` group (requires logout/login to take effect)
3. Copies systemd service file to `/etc/systemd/system/ydotoold.service`
4. Runs `systemctl daemon-reload`
5. Runs `systemctl enable ydotoold` (enables service to start on boot)
6. Runs `systemctl start ydotoold` (starts service immediately)

**Service File Configuration** (`ydotool/ydotoold.service`):
- Type: simple
- ExecStart: `/usr/bin/ydotoold`
- After: graphical.target
- Restart: on-failure
- WantedBy: multi-user.target

**Problem**: Despite these steps, after restart the daemon is not running.

## Scripts Involved

The following scripts need to be updated to use `ydotool` instead of `xdotool`:

1. **`kde/scripts/kwin-center-cursor.sh`** - Core script that centers cursor on active window
   - Currently uses `xdotool` for all operations
   - Needs to be updated to use `ydotool` for mouse movement
   - Needs to use `qdbus` (already available) to query KWin for window information instead of `xdotool getactivewindow` and `getwindowgeometry`

2. **`kde/scripts/kwin-switch-*.sh`** (left, right, up, down) - Switch windows and center cursor
   - Triggered by Meta+HJKL keybinds
   - Call `kwin-center-cursor.sh` after switching

3. **`kde/scripts/kwin-move-screen-*.sh`** (left, right, up, down) - Move windows between screens and center cursor
   - Triggered by Meta+Shift+HJKL keybinds
   - Call `kwin-center-cursor.sh` after moving

**Script Registration** (`kde/apply-scripts.sh`):
- Installs scripts to `~/.local/bin`
- Creates desktop files for each script
- Registers shortcuts in `kglobalshortcutsrc` using `kwriteconfig5`
- Keybinds: Meta+HJKL for switching, Meta+Shift+HJKL for moving

## Current Blocker

The `ydotoold` service is not starting automatically after reboot. This prevents any testing or implementation of `ydotool` functionality because the daemon must be running for `ydotool` commands to work.

**Investigation Needed**:
1. Check service status: `systemctl status ydotoold`
2. Check if service is enabled: `systemctl is-enabled ydotoold`
3. Review service logs: `journalctl -u ydotoold -n 50`
4. Verify service file exists and has correct permissions: `ls -la /etc/systemd/system/ydotoold.service`
5. Verify service file content matches expected configuration
6. Attempt manual start: `sudo systemctl start ydotoold` and observe any errors
7. Check for permission issues or missing dependencies
8. Verify `/usr/bin/ydotoold` executable exists and is executable
9. Check if service has proper dependencies (e.g., graphical.target may not be available early enough)

## Test Infrastructure

There is a test script (`ydotool-test.sh`) that:
- Checks if `ydotool` is installed
- Checks if `ydotoold` daemon is running
- Checks if user is in `input` group
- Tests mouse movement functionality

This script cannot be used until the daemon is running.

## Next Steps (After Service Issue Resolved)

Once the `ydotoold` service is running reliably:
1. Verify `ydotool` mouse movement commands work
2. Modify `kwin-center-cursor.sh` to:
   - Use `qdbus` to query KWin for active window information (replacing `xdotool getactivewindow`)
   - Use `qdbus` to get window geometry (replacing `xdotool getwindowgeometry`)
   - Use `ydotool mousemove --absolute X Y` to move cursor (replacing `xdotool mousemove`)
3. Test all scripts with keybinds to ensure cursor movement works correctly
4. Update `kde/apply-scripts.sh` to check for `ydotool` instead of `xdotool` on Wayland

## Questions for Clarification

1. What is the current status of the `ydotoold` service? (enabled, disabled, failed, etc.)
2. Are there any error messages in the service logs (`journalctl -u ydotoold`)?
3. Can the service be started manually with `sudo systemctl start ydotoold`?
4. Does `/usr/bin/ydotoold` exist and is it executable?
5. Is the user still logged in after the restart, or did they need to log out/in for the `input` group membership to take effect?




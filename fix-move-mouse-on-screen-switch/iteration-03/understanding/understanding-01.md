# Understanding: Verification of ydotool Functionality Before Script Modification

## Problem Context

The KDE keyboard shortcut scripts that center the mouse cursor after window switching/moving stopped working after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

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
- Created `ydotool/` package with installation script (`ydotool/install.sh`)
- Set up systemd service for `ydotoold` daemon (`ydotool/ydotoold.service`)
- Integrated into main dotfiles installation flow (added to `install.sh` INSTALL_ORDER)
- Installation script executed successfully
- User has installed ydotool and restarted (group membership should now be active)

**Key Insight**: Installation is complete, but functionality needs to be verified before proceeding with script modifications.

## Current State Understanding

### Installation Status

Based on Iteration 02 implementation:

1. **ydotool Package**: Created at `ydotool/install.sh`
   - Installs `ydotool` via `apt install ydotool`
   - Adds user to `input` group via `sudo usermod -aG input $USER`
   - Copies service file to `/etc/systemd/system/ydotoold.service`
   - Enables and starts the service via `systemctl enable ydotoold` and `systemctl start ydotoold`

2. **Service Configuration**: `ydotool/ydotoold.service`
   - Type: simple
   - ExecStart: `/usr/bin/ydotoold`
   - Restart: on-failure with 5 second delay
   - WantedBy: multi-user.target

3. **Integration**: Added to main `install.sh` before KDE setup

### Expected State After Installation

After running the installation script and restarting (for group membership):
- `ydotool` binary should be available at `/usr/bin/ydotool`
- User should be in `input` group (requires logout/login)
- `ydotoold` service should be enabled and running
- `/dev/uinput` should be accessible (via group membership)

## Current Iteration Goals

This iteration focuses on **verification** before proceeding with script modifications:

1. **Verify daemon status**: Confirm `ydotoold` service is running
2. **Test ydotool functionality**: Verify mouse movement commands work correctly
3. **Validate permissions**: Ensure user can execute ydotool commands without issues
4. **Document test results**: Record what works and any issues encountered

## Verification Steps Needed

### Step 1: Check Daemon Status
- Command: `systemctl is-active ydotoold` (or `systemctl status ydotoold`)
- Expected: Service should be "active (running)"
- If not running: Need to start it and investigate why it didn't start automatically

### Step 2: Verify Group Membership
- Command: `groups | grep input`
- Expected: Should show `input` in the output
- If not present: User may need to log out/in again, or group addition didn't work

### Step 3: Test Absolute Mouse Movement
- Command: `ydotool mousemove --absolute -x 100 -y 100`
- Expected: Cursor should move to coordinates (100, 100) on screen
- If fails: Check daemon status, permissions, or error messages

### Step 4: Test Relative Mouse Movement
- Command: `ydotool mousemove -x 10 -y 10`
- Expected: Cursor should move 10 pixels right and 10 pixels down from current position
- If fails: Similar troubleshooting as absolute movement

### Step 5: Verify Coordinate System
- Test with different screen positions to understand coordinate system
- Check if coordinates are screen-relative or window-relative
- Test multi-monitor behavior (if applicable)

## Potential Issues to Watch For

1. **Daemon Not Running**
   - Service may have failed to start
   - Check logs: `journalctl -u ydotoold` or `journalctl -u ydotoold.service`
   - May need to investigate why service didn't start

2. **Permission Denied**
   - User may not be in `input` group yet (requires logout/login)
   - `/dev/uinput` may have incorrect permissions
   - Check: `ls -l /dev/uinput` and `groups | grep input`

3. **Connection Errors**
   - `ydotool` may not be able to connect to `ydotoold`
   - Check if daemon is listening: `ps aux | grep ydotoold`
   - May need to restart daemon

4. **Coordinate System Confusion**
   - Need to understand if coordinates are absolute screen coordinates or relative
   - Multi-monitor setups may affect coordinate calculations
   - May need to test with different positions to understand behavior

## Next Steps After Verification

Once verification is complete and ydotool is confirmed working:

1. **Research KWin D-Bus Methods**: Need to find exact methods to:
   - Get active window ID: `qdbus org.kde.KWin /KWin org.kde.KWin.activeWindow`
   - Get window geometry (X, Y, WIDTH, HEIGHT) from window ID
   - Parse `qdbus` output format

2. **Modify `kwin-center-cursor.sh`**: Replace `xdotool` calls with:
   - `qdbus` queries for window information
   - `ydotool` commands for cursor movement

3. **Update `apply-scripts.sh`**: Change dependency check from `xdotool` to `ydotool`

4. **Test Script Modifications**: Verify cursor centering works correctly with modified scripts

## Open Questions

1. **Is the daemon actually running?** Need to verify service status
2. **Are permissions correct?** Need to check group membership and `/dev/uinput` access
3. **Does ydotool work as expected?** Need to test mouse movement commands
4. **What is the coordinate system?** Need to understand how ydotool interprets coordinates
5. **What are the exact KWin D-Bus methods?** Need to research window geometry queries

## Key Dependencies

- `ydotool` package must be installed
- `ydotoold` daemon must be running
- User must be in `input` group (requires logout/login)
- `/dev/uinput` must be accessible

## Success Criteria

Before proceeding to script modifications:
- [ ] `ydotoold` service is running
- [ ] User is in `input` group
- [ ] `ydotool mousemove --absolute` works correctly
- [ ] `ydotool mousemove` (relative) works correctly
- [ ] Coordinate system is understood
- [ ] No permission or connection errors

## Notes

- This iteration is focused on verification, not implementation
- All script modifications will happen in a future iteration after verification is complete
- The goal is to ensure the foundation (ydotool) works before building on top of it





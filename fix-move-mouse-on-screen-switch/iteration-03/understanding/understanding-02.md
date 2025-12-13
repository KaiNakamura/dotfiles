# Understanding: Current Blocker - Missing ydotoold Package

## Problem Context

The KDE keyboard shortcut scripts that center the mouse cursor after window switching/moving stopped working after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh` - centers cursor on active window

**Current Implementation** (X11):
- Uses `xdotool getactivewindow` to get window ID
- Uses `xdotool getwindowgeometry` to get window position/size  
- Uses `xdotool mousemove` to move cursor

## Previous Iteration Summary

**Iteration 01**: Attempted to implement ydotool integration but was blocked at Phase 1.2 verification:
- `ydotool` is installed but `ydotoold` daemon not running
- Permission issues with `/dev/uinput` access
- Verification cannot proceed without daemon setup

**Iteration 02**: Completed the installation infrastructure:
- Created `ydotool/` package with installation script (`ydotool/install.sh`)
- Set up systemd service for `ydotoold` daemon (`ydotool/ydotoold.service`)
- Integrated into main dotfiles installation flow (added to `install.sh` INSTALL_ORDER)
- Installation script executed successfully
- User has installed ydotool and restarted (group membership should now be active)

**Iteration 03**: Attempted Phase 1 verification but discovered installation script bug:
- Verified `ydotool` CLI tool is installed at `/usr/bin/ydotool`
- Confirmed user is in `input` group (group ID 995)
- Discovered `ydotoold` daemon service is failing to start
- Service failure with exit code 203/EXEC indicates missing executable file
- Investigation revealed `/usr/bin/ydotoold` doesn't exist

## Current State Understanding

### Installation Status

**What's Installed**:
- ✅ `ydotool` package (CLI tool) - version 0.1.8-3build1
- ✅ User `kai` is in `input` group (group ID 995)
- ✅ Systemd service file exists at `/etc/systemd/system/ydotoold.service`
- ✅ Service is enabled (will start on boot once executable exists)

**What's Missing**:
- ❌ `ydotoold` package (daemon) - NOT installed
- ❌ `/usr/bin/ydotoold` executable - doesn't exist
- ❌ Daemon cannot start because executable is missing

### Root Cause Analysis

The installation script (`ydotool/install.sh`) has a bug:
- **Line 11**: Only installs `ydotool` package: `sudo apt install -y ydotool`
- **Missing**: Does not install `ydotoold` package (the daemon)
- **Impact**: Service file references `/usr/bin/ydotoold` (line 7 of `ydotoold.service`), but the executable doesn't exist because the package wasn't installed

**Package Structure**:
- `ydotool` - CLI tool for sending commands to the daemon
- `ydotoold` - Daemon that handles actual input device access (separate package)

### Service Status

**Current State**:
- Service is enabled: `systemctl is-enabled ydotoold` → `enabled`
- Service status: `activating (auto-restart)` with `Result: exit-code`
- Exit code: `203/EXEC` - indicates the executable file referenced in `ExecStart` doesn't exist
- Service keeps trying to restart but fails immediately because `/usr/bin/ydotoold` is missing

**Service Configuration** (`ydotool/ydotoold.service`):
- ExecStart: `/usr/bin/ydotoold`
- Type: simple
- Restart: on-failure with 5 second delay
- WantedBy: multi-user.target

### Test Script Status

Created `ydotool-test.sh` to verify functionality:
- Checks if `ydotool` CLI is installed ✅
- Checks if daemon is running ❌ (fails because daemon can't start)
- Checks group membership ✅
- Tests mouse movement ❌ (can't test without daemon)

## Current Blocker

**Primary Blocker**: Installation script is incomplete
- The `ydotool/install.sh` script only installs the CLI tool (`ydotool`) but not the daemon package (`ydotoold`)
- Without the daemon executable, the systemd service cannot start
- Without the daemon running, `ydotool` commands cannot execute (they need to communicate with the daemon)

**Fix Required**: Update `ydotool/install.sh` to install both packages:
```bash
sudo apt install -y ydotool ydotoold
```

## Verification Status

**Completed**:
- ✅ ydotool CLI tool is installed
- ✅ User is in `input` group
- ✅ Service file is properly configured
- ✅ Service is enabled
- ✅ Identified root cause of daemon failure

**Pending** (blocked by missing package):
- ⏳ Daemon service running
- ⏳ Mouse movement command testing
- ⏳ Coordinate system verification
- ⏳ Multi-monitor behavior testing

## Next Steps After Fix

Once the installation script is fixed and `ydotoold` package is installed:

1. **Install the missing package**: Run `sudo apt install -y ydotoold`
2. **Start the daemon**: Service should start automatically, or manually with `sudo systemctl start ydotoold`
3. **Verify daemon is running**: `systemctl status ydotoold` should show `active (running)`
4. **Test mouse movement**: Run `ydotool-test.sh` or manually test `ydotool mousemove --absolute 100 100`
5. **Proceed to Phase 2**: Once verification is complete, proceed with script modifications

## Key Dependencies

- `ydotool` package (CLI tool) - ✅ Installed
- `ydotoold` package (daemon) - ❌ Missing
- User in `input` group - ✅ Complete
- `/dev/uinput` access - ⏳ Will work once daemon is running (daemon handles uinput access)
- Systemd service - ✅ Configured and enabled (waiting for executable)

## Success Criteria

Before proceeding to script modifications:
- [ ] `ydotoold` package is installed
- [ ] `/usr/bin/ydotoold` executable exists
- [ ] `ydotoold` service is running (`systemctl status ydotoold` shows active)
- [ ] `ydotool mousemove --absolute` works correctly
- [ ] `ydotool mousemove` (relative) works correctly
- [ ] Coordinate system is understood
- [ ] No permission or connection errors

## Notes

- The installation script bug was discovered during Iteration 03 verification phase
- This is a straightforward fix - just need to add `ydotoold` to the package installation command
- Once fixed, the service should start automatically since it's already enabled
- Verification can proceed once the daemon is running
- All script modifications are blocked until verification is complete





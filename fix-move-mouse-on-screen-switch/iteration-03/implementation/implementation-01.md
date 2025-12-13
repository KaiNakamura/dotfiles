# Implementation 01: Phase 1 - ydotool Verification & Testing

## Date
2024-12-18

## Objective
Verify ydotool setup and test mouse movement commands as specified in Phase 1 of the plan.

## Findings

### 1. ydotool Installation Status
- ✅ **ydotool is installed**: Located at `/usr/bin/ydotool`
- ✅ **User in input group**: User `kai` is a member of the `input` group (group ID 995)
- ⚠️ **ydotoold daemon not running**: Service exists but is inactive (dead)
- ⚠️ **uinput device permissions**: `/dev/uinput` exists but is owned by root with `crw-------` permissions (only root can access)

### 2. ydotool Command Syntax
- **Available commands**: `type`, `recorder`, `mousemove`, `key`, `click`
- **Mouse movement syntax**: `ydotool mousemove --absolute X Y`
  - Uses `--absolute` flag for absolute screen coordinates
  - Takes X and Y as separate arguments
  - Example: `ydotool mousemove --absolute 100 100`

### 3. Current Script Analysis
The target script `kde/scripts/kwin-center-cursor.sh` currently uses:
- `xdotool getactivewindow` - Get active window ID
- `xdotool getwindowgeometry --shell` - Get window geometry (X, Y, WIDTH, HEIGHT)
- `xdotool mousemove $CENTER_X $CENTER_Y` - Move mouse to absolute coordinates

The replacement will be:
- `qdbus` - Query KWin D-Bus for active window and geometry
- `ydotool mousemove --absolute $CENTER_X $CENTER_Y` - Move mouse to absolute coordinates

### 4. Daemon Status
- **System service**: `/etc/systemd/system/ydotoold.service` exists and is enabled
- **Service status**: Inactive (dead) - needs to be started
- **Manual start attempt**: Failed (likely requires root permissions or proper systemd setup)

## Issues Identified

1. **Daemon not running**: The `ydotoold` service needs to be started before ydotool commands will work
   - Requires: `sudo systemctl start ydotoold` (or restart if already attempted)
   - Service is enabled, so it should start on boot once started once

2. **Permission verification**: While user is in `input` group, the daemon needs to be running to handle uinput access
   - The daemon runs as root and manages uinput device access
   - Once daemon is running, ydotool commands should work for users in the `input` group

## Test Script Created

Created `ydotool-test.sh` to verify functionality once daemon is running:
- Checks if daemon is running
- Tests basic mouse movement command
- Provides feedback on success/failure

## Next Steps

1. **Start the daemon**: User needs to run `sudo systemctl start ydotoold` to start the service
2. **Verify daemon is running**: Check with `systemctl status ydotoold` or `pgrep ydotoold`
3. **Test mouse movement**: Run test script or manually test `ydotool mousemove --absolute X Y`
4. **Document coordinate system**: Verify that ydotool uses screen-absolute coordinates (same as xdotool)
5. **Proceed to Phase 2**: Once mouse movement is confirmed working, proceed to script modification

## Blockers

- **Daemon not running**: Cannot test mouse movement until daemon is started
- **Requires sudo**: Starting the daemon requires root privileges

## Status

⏳ **Phase 1 Part 1 (ydotool verification)**: In progress - blocked on daemon startup
- ✅ Installation verified
- ✅ Group membership verified  
- ✅ Command syntax researched
- ⏳ Daemon startup (requires user action)
- ⏳ Mouse movement testing (pending daemon)





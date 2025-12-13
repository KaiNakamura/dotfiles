# Plan: Verify ydotool Functionality (Concept 1 - Verification Only)

## Overview

This plan focuses **exclusively** on verifying that `ydotool` can be successfully installed and run. No script modifications will be made in this iteration - that will be saved for later iterations once verification is complete.

**Approach**: Concept 1 (ydotool + qdbus) - but only the verification phase.

## Current State

- ✅ `ydotool` CLI package is installed (`/usr/bin/ydotool` exists)
- ✅ User `kai` is in `input` group (group ID 995)
- ✅ Systemd service file exists and is enabled (`/etc/systemd/system/ydotoold.service`)
- ❌ `ydotoold` daemon package is **NOT** installed (`/usr/bin/ydotoold` doesn't exist)
- ❌ Daemon service cannot start (exit code 203/EXEC - missing executable)
- ❌ ydotool functionality cannot be verified until daemon is running

## Root Cause

The installation script (`ydotool/install.sh`) has a bug:
- **Line 11**: Only installs `ydotool` package: `sudo apt install -y ydotool`
- **Missing**: Does not install `ydotoold` package (the daemon)
- **Impact**: Service file references `/usr/bin/ydotoold`, but executable doesn't exist

## Plan: Verification Steps

### Step 1: Fix Installation Script Bug

**Goal**: Update installation script to install both required packages

**Action**:
- Modify `ydotool/install.sh` line 11
- Change from: `sudo apt install -y ydotool`
- Change to: `sudo apt install -y ydotool ydotoold`

**Verification**:
- Script should install both packages
- `/usr/bin/ydotoold` should exist after installation

### Step 2: Install Missing Package

**Goal**: Install the `ydotoold` package so the daemon executable exists

**Action**:
- Run the updated installation script, OR
- Manually run: `sudo apt install -y ydotoold`

**Verification**:
- Check that `/usr/bin/ydotoold` exists: `test -f /usr/bin/ydotoold && echo "exists"`
- Verify package is installed: `dpkg -l | grep ydotoold`

### Step 3: Verify Daemon Service Starts

**Goal**: Ensure the systemd service can start successfully

**Action**:
- Service should start automatically (it's already enabled), OR
- Manually start: `sudo systemctl start ydotoold`
- Check status: `systemctl status ydotoold`

**Verification**:
- Service status should show `active (running)`
- No exit code errors (203/EXEC should be resolved)
- Process should be running: `pgrep -x ydotoold` should return PID

### Step 4: Verify ydotool Mouse Movement Commands

**Goal**: Test that ydotool can successfully move the mouse cursor

**Action**:
- Run the existing test script: `./ydotool-test.sh`
- Or manually test:
  - `ydotool mousemove --absolute 100 100` (absolute coordinates)
  - `ydotool mousemove 50 50` (relative movement)

**Verification**:
- Commands execute without errors
- Mouse cursor actually moves to expected position
- No permission errors
- No connection errors (daemon communication works)

### Step 5: Understand Coordinate System (Optional)

**Goal**: Document how ydotool's coordinate system works for future reference

**Action**:
- Test absolute coordinates at various screen positions
- Test relative movement
- Document findings (screen-absolute vs window-relative, origin point, etc.)

**Verification**:
- Coordinate system behavior is understood
- Notes documented for future script modifications

## Success Criteria

Before this iteration is considered complete:

- [ ] `ydotoold` package is installed
- [ ] `/usr/bin/ydotoold` executable exists
- [ ] `ydotoold` service is running (`systemctl status ydotoold` shows `active (running)`)
- [ ] `ydotool mousemove --absolute` command works correctly
- [ ] `ydotool mousemove` (relative) command works correctly
- [ ] No permission or connection errors
- [ ] Coordinate system is understood (documented)

## Out of Scope (Future Iterations)

**Explicitly NOT included in this iteration**:
- ❌ Script modifications (`kwin-center-cursor.sh`)
- ❌ KWin D-Bus research
- ❌ qdbus integration
- ❌ Coordinate calculations for window centering
- ❌ Error handling in scripts
- ❌ Multi-monitor testing (unless needed for basic verification)

## Implementation Order

1. **Fix installation script** (`ydotool/install.sh`)
2. **Install missing package** (run updated script or manual install)
3. **Verify daemon starts** (check service status)
4. **Test mouse movement** (run test script)
5. **Document coordinate system** (optional, for future reference)

## Notes

- This is a verification-only iteration
- All script modifications will be deferred to later iterations
- Focus is on ensuring the foundation (ydotool) works before building on top of it
- Once verification is complete, future iterations can proceed with script modifications





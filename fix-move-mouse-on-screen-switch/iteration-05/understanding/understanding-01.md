# Understanding: Getting ydotool-test.sh Working

## Goal Shift

The user wants to pivot from fixing the systemd service startup issues to a smaller, more focused goal: **just getting `ydotool-test.sh` working**. This is a good incremental approach - get the basic functionality working first, then worry about automatic startup later.

## Current State

### What's Working
- ✅ `ydotool` CLI tool is installed at `/usr/bin/ydotool`
- ✅ `ydotoold` daemon is running (PID: 29917) - user successfully started it manually with `sudo systemctl start ydotoold`
- ✅ User (`kai`) is in the `input` group (confirmed via `groups` command)
- ✅ `/dev/uinput` device exists

### What's Failing
When running `./ydotool-test.sh`, the script correctly detects all prerequisites:
- ✅ ydotool is installed
- ✅ ydotoold daemon is running
- ✅ User is in 'input' group

However, when executing the actual mouse movement command:
```bash
ydotool mousemove --absolute 100 100
```

It fails with:
```
ydotool: notice: ydotoold backend unavailable (may have latency+delay issues)
terminate called after throwing an instance of 'std::runtime_error'
  what():  failed to open uinput device
```

The command aborts with a core dump.

## Root Cause Analysis

### The Permission Problem

The `/dev/uinput` device has restrictive permissions:
```
crw------- 10,223 root 12 Dec 18:46 /dev/uinput
```

This means:
- **Owner (root)**: read/write access (`rw-`)
- **Group**: no access (`---`)
- **Others**: no access (`---`)

Even though:
1. The user is in the `input` group
2. The daemon is running as root (from service file: `User=root`)

The device permissions don't allow group access, so members of the `input` group cannot access `/dev/uinput`.

### Why This Matters

Based on research:
- `ydotoold` daemon needs access to `/dev/uinput` to create virtual input devices
- Even though the daemon runs as root, if it can't properly initialize or access uinput, it won't function correctly
- The error "ydotoold backend unavailable" suggests the CLI can't communicate with the daemon, possibly because the daemon failed to initialize properly
- The "failed to open uinput device" error confirms that something is trying to access uinput but lacks permissions

### Missing Configuration

The install script (`ydotool/install.sh`) currently:
- ✅ Installs `ydotool` and `ydotoold` packages
- ✅ Adds user to `input` group
- ✅ Configures uinput module to load at boot (`uinput.conf`)
- ✅ Sets up systemd service

**But it's missing:**
- ❌ A udev rule to set proper permissions on `/dev/uinput`

## The Solution Approach

To fix this, we need to create a **udev rule** that sets appropriate permissions on `/dev/uinput` when the device is created. The standard approach is:

1. Create a udev rule file: `/etc/udev/rules.d/99-uinput.rules`
2. Rule content should set: `MODE="0660"` and `GROUP="input"`
3. This allows members of the `input` group to read/write the device
4. Reload udev rules: `sudo udevadm control --reload-rules`
5. Trigger the rule: `sudo udevadm trigger` (or unload/reload uinput module)

## Questions for Clarification

1. **Scope**: Should we update the `ydotool/install.sh` script to include the udev rule creation, or just manually create it for now to get the test working?

2. **Testing approach**: After creating the udev rule, should we:
   - Test with the current daemon process (restart it?)
   - Or restart the system to ensure everything works from a clean boot?

3. **Module loading**: The `uinput` module appears to be loaded (device exists), but should we verify it's loaded and ensure it loads at boot?

4. **Service file**: Should we also fix the `StartLimitIntervalSec` compatibility issue in the service file while we're at it, or focus solely on getting the test script working first?

## Expected Outcome

After implementing the udev rule:
- `/dev/uinput` should have permissions like `crw-rw----` (group read/write)
- The `ydotoold` daemon should be able to properly initialize and access uinput
- The `ydotool` CLI should be able to communicate with the daemon
- `ydotool-test.sh` should successfully move the mouse cursor



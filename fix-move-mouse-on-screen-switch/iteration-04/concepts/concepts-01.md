# Concepts: Diagnosing ydotoold Service Startup Failure

## Problem Summary

The `ydotoold` systemd service is not running after installation script execution and system restart. The installation script:
- Installs both `ydotool` and `ydotoold` packages
- Adds user to `input` group
- Copies systemd service file to `/etc/systemd/system/ydotoold.service`
- Runs `systemctl daemon-reload`, `enable`, and `start`

Despite these steps, the daemon is not running after reboot.

## Recommended Concepts (Best to Worst)

### Option 1: Diagnostic-First Approach - Check Service Status and Logs ⭐ **RECOMMENDED**

**Description**: Systematically diagnose the issue by checking service status, logs, and configuration before making changes.

**Approach**:
1. Check current service status: `systemctl status ydotoold`
2. Check if service is enabled: `systemctl is-enabled ydotoold`
3. Review service logs: `journalctl -u ydotoold -n 100` (look for error messages)
4. Verify service file exists and has correct permissions: `ls -la /etc/systemd/system/ydotoold.service`
5. Verify service file content matches expected configuration
6. Attempt manual start: `sudo systemctl start ydotoold` and observe output
7. Check if `/usr/bin/ydotoold` executable exists: `ls -la /usr/bin/ydotoold`
8. Check if `uinput` kernel module is loaded: `lsmod | grep uinput`
9. Based on findings, apply targeted fix

**Pros**:
- Identifies root cause before making changes
- Prevents unnecessary modifications
- Provides clear error messages to guide solution
- Most efficient approach - fixes the actual problem
- Follows systematic troubleshooting methodology

**Cons**:
- Requires manual investigation steps
- May reveal multiple issues that need sequential fixes
- Takes time to gather diagnostic information

**When to Use**: Always start here - this is the most logical first step.

---

### Option 2: Fix Service Dependencies - Change After= and WantedBy Targets

**Description**: The service file uses `After=graphical.target` but `WantedBy=multi-user.target`. This mismatch might cause timing issues where the service tries to start before graphical.target is ready, or multi-user.target doesn't wait for graphical.target.

**Approach**:
1. Change service file to use `After=graphical.target` with `WantedBy=graphical.target` (for Wayland/KDE)
2. OR change to `After=multi-user.target` with `WantedBy=multi-user.target` (simpler, earlier startup)
3. OR use `After=display-manager.service` if using a display manager
4. Reload systemd and restart service

**Pros**:
- Addresses common systemd dependency/timing issues
- Simple configuration change
- Can resolve startup ordering problems

**Cons**:
- May not be the actual problem
- Could cause service to start too early (before Wayland is ready)
- Requires understanding of systemd target relationships

**When to Use**: If logs show service timing issues or if Option 1 reveals dependency problems.

---

### Option 3: Ensure uinput Kernel Module is Loaded

**Description**: `ydotoold` requires the `uinput` kernel module to access `/dev/uinput`. If the module isn't loaded at boot, the service will fail silently.

**Approach**:
1. Check if `uinput` module is loaded: `lsmod | grep uinput`
2. If not loaded, load it: `sudo modprobe uinput`
3. Make it persistent: Create `/etc/modules-load.d/uinput.conf` with content `uinput`
4. Add `After=systemd-modules-load.service` to service file to ensure module loads first
5. Restart service

**Pros**:
- Addresses a common root cause (missing kernel module)
- Required for `/dev/uinput` access
- Simple fix if this is the issue

**Cons**:
- May not be the problem if module loads automatically
- Requires kernel module knowledge
- Might mask other permission issues

**When to Use**: If Option 1 reveals missing `uinput` module or `/dev/uinput` access errors.

---

### Option 4: Fix Service File Permissions and Ownership

**Description**: The service file might have incorrect permissions or ownership, preventing systemd from reading it properly.

**Approach**:
1. Check service file permissions: `ls -la /etc/systemd/system/ydotoold.service`
2. Ensure correct permissions: `sudo chmod 644 /etc/systemd/system/ydotoold.service`
3. Ensure root ownership: `sudo chown root:root /etc/systemd/system/ydotoold.service`
4. Reload systemd: `sudo systemctl daemon-reload`
5. Restart service

**Pros**:
- Fixes permission-related startup failures
- Simple and quick
- Common systemd issue

**Cons**:
- Unlikely to be the problem (install script uses `sudo cp`)
- May not address actual root cause

**When to Use**: If Option 1 shows permission errors in logs or file listing.

---

### Option 5: Add User/Group and Environment Variables to Service

**Description**: The service might need explicit user/group specification or environment variables to function correctly in Wayland.

**Approach**:
1. Modify service file to add:
   - `User=root` (or specific user)
   - `Group=input` (or root)
   - Environment variables if needed (e.g., `WAYLAND_DISPLAY`)
2. Add `StandardOutput=journal` and `StandardError=journal` for better logging
3. Reload and restart

**Pros**:
- Ensures service runs with correct permissions
- Better logging for debugging
- Can resolve permission issues

**Cons**:
- Running as root may be unnecessary
- May not be the actual problem
- Adds complexity

**When to Use**: If Option 1 reveals permission errors or if service needs specific environment variables.

---

### Option 6: Use User Systemd Service Instead of System Service

**Description**: Instead of a system-wide service, create a user service that starts when the user logs in (better for Wayland/KDE).

**Approach**:
1. Move service file from `/etc/systemd/system/` to `~/.config/systemd/user/`
2. Change service to use `WantedBy=default.target` (user services use different targets)
3. Enable with `systemctl --user enable ydotoold`
4. Start with `systemctl --user start ydotoold`
5. Enable lingering: `loginctl enable-linger $USER` (allows user services to run without active session)

**Pros**:
- Better integration with Wayland/KDE user sessions
- No need for root permissions
- Starts with user login automatically
- More appropriate for user-space tools

**Cons**:
- Requires different service management commands
- May need `loginctl enable-linger` for persistence
- Different approach than current installation script

**When to Use**: If system service approach continues to fail or if Wayland requires user-level services.

---

### Option 7: Check for Conflicting Services or Processes

**Description**: Another process might be using `/dev/uinput` or conflicting with `ydotoold`.

**Approach**:
1. Check for existing `ydotoold` processes: `ps aux | grep ydotoold`
2. Check what's using `/dev/uinput`: `sudo lsof /dev/uinput`
3. Check for socket conflicts: `ls -la /tmp/.ydotool_socket*` or check default socket location
4. Stop conflicting processes/services
5. Restart `ydotoold`

**Pros**:
- Identifies resource conflicts
- Can resolve blocking issues
- Reveals system state problems

**Cons**:
- Unlikely if service never started
- May not be the root cause
- Requires process investigation

**When to Use**: If Option 1 shows resource conflicts or if manual start fails with "already in use" errors.

---

### Option 8: Reinstall and Verify Package Installation

**Description**: The packages might not have installed correctly, or the executable might be missing or corrupted.

**Approach**:
1. Verify packages are installed: `dpkg -l | grep ydotool`
2. Check executable exists: `ls -la /usr/bin/ydotoold`
3. Test executable manually: `sudo /usr/bin/ydotoold` (should start daemon)
4. If issues found, reinstall: `sudo apt remove --purge ydotool ydotoold && sudo apt install -y ydotool ydotoold`
5. Re-run installation script

**Pros**:
- Fixes corrupted or incomplete installations
- Verifies package integrity
- Ensures all components are present

**Cons**:
- Unlikely if packages installed successfully
- Time-consuming
- May not address configuration issues

**When to Use**: If Option 1 reveals missing executables or if manual execution fails immediately.

---

## Recommended Approach

**Start with Option 1** (Diagnostic-First) to identify the root cause. Based on the findings:

- **If logs show dependency/timing issues** → Use Option 2
- **If logs show missing `/dev/uinput` or kernel module errors** → Use Option 3
- **If logs show permission errors** → Use Option 4 or 5
- **If system service approach fails completely** → Consider Option 6 (user service)
- **If executable is missing or corrupted** → Use Option 8
- **If resource conflicts detected** → Use Option 7

## Key Diagnostic Commands

Before choosing a solution, run these commands:

```bash
# Service status
systemctl status ydotoold
systemctl is-enabled ydotoold

# Service logs
journalctl -u ydotoold -n 100
journalctl -u ydotoold --since "today"

# Service file verification
ls -la /etc/systemd/system/ydotoold.service
cat /etc/systemd/system/ydotoold.service

# Executable verification
ls -la /usr/bin/ydotoold
file /usr/bin/ydotoold

# Kernel module check
lsmod | grep uinput
ls -la /dev/uinput

# Manual start test
sudo systemctl start ydotoold
systemctl status ydotoold
```

## Questions to Consider

1. What does `systemctl status ydotoold` show? (active, inactive, failed, etc.)
2. Are there any error messages in `journalctl -u ydotoold`?
3. Can the service be started manually with `sudo systemctl start ydotoold`?
4. Is the `uinput` kernel module loaded?
5. Does `/usr/bin/ydotoold` exist and execute without errors when run manually?
6. Are there any permission errors in the logs?




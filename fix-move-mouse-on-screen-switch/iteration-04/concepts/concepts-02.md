# Concepts: Ensuring ydotoold Always Stays Running

## Problem Summary

After resolving the initial startup issue (covered in concepts-01.md), we need to ensure `ydotoold`:
1. Starts reliably on boot
2. Stays running if it crashes
3. Handles permission and resource issues gracefully
4. Recovers from failures automatically
5. Works correctly in Wayland/KDE environment

## Recommended Concepts (Best to Worst)

### Option 1: Enhanced Systemd Service with Robust Restart Policy ⭐ **RECOMMENDED**

**Description**: Improve the existing systemd service file with better restart policies, dependencies, and error handling to ensure it stays running.

**Approach**:
1. Update service file with:
   - `Restart=always` (instead of `on-failure`) - restarts even on successful exit
   - `RestartSec=5` - wait 5 seconds before restarting
   - `StartLimitIntervalSec=0` - disable rate limiting (allows unlimited restarts)
   - `After=systemd-modules-load.service` - ensure uinput module loads first
   - `After=graphical.target` or `After=display-manager.service` - ensure Wayland is ready
   - `WantedBy=graphical.target` - start with graphical session (for Wayland)
   - `StandardOutput=journal` and `StandardError=journal` - capture all logs
   - `User=root` - explicit user (ydotoold needs root for /dev/uinput)
   - `Group=input` - explicit group
2. Ensure uinput module loads at boot: Create `/etc/modules-load.d/uinput.conf`
3. Add systemd timer or watchdog if needed for health checks

**Pros**:
- Leverages existing systemd infrastructure
- Automatic restart on any failure
- No rate limiting means it will keep trying
- Better logging for troubleshooting
- Standard Linux approach
- Works with existing installation script

**Cons**:
- Requires root privileges
- May restart too aggressively if there's a persistent issue
- Need to ensure dependencies are correct

**When to Use**: Primary approach - most robust and standard solution.

---

### Option 2: User Systemd Service with Lingering Enabled

**Description**: Use a user-level systemd service that starts when user logs in, with lingering enabled so it persists even when not logged in.

**Approach**:
1. Create service file at `~/.config/systemd/user/ydotoold.service`
2. Configure with:
   - `Restart=always`
   - `RestartSec=5`
   - `WantedBy=default.target`
   - `After=graphical-session.target`
3. Enable lingering: `loginctl enable-linger $USER` (allows user services to run without active session)
4. Enable and start: `systemctl --user enable --now ydotoold`
5. Update installation script to use user service instead of system service

**Pros**:
- Better integration with Wayland/KDE user sessions
- No root privileges needed for management
- Starts automatically with user login
- Lingering keeps it running even when logged out
- More appropriate for user-space tools

**Cons**:
- Requires different service management commands
- User must be logged in (unless lingering enabled)
- Different approach than current installation script
- May need to handle permission issues differently

**When to Use**: If system service approach has issues or if Wayland requires user-level services.

---

### Option 3: Systemd Service with Watchdog Timer

**Description**: Add a systemd timer that periodically checks if ydotoold is running and restarts it if not.

**Approach**:
1. Create systemd timer unit: `ydotoold-watchdog.timer`
2. Create systemd service unit: `ydotoold-watchdog.service` that checks if ydotoold is running
3. Timer runs every 30 seconds or 1 minute
4. Service checks `pgrep ydotoold` and starts it if not running
5. Enable both timer and service

**Pros**:
- Provides additional layer of protection
- Can detect and fix issues that systemd restart might miss
- Can log when it detects and fixes problems
- Works alongside systemd service restart policy

**Cons**:
- Adds complexity
- May be redundant if systemd restart works correctly
- Requires maintaining additional units
- Slight resource overhead

**When to Use**: If systemd restart policy isn't sufficient or if you want extra monitoring.

---

### Option 4: Ensure uinput Module Loads at Boot

**Description**: Make sure the `uinput` kernel module loads automatically at boot, which is required for `/dev/uinput` access.

**Approach**:
1. Check if module loads automatically: `lsmod | grep uinput` after reboot
2. If not, create `/etc/modules-load.d/uinput.conf` with content: `uinput`
3. Add `After=systemd-modules-load.service` to ydotoold service file
4. Test by rebooting and checking `lsmod | grep uinput`

**Pros**:
- Required for ydotoold to function
- Simple configuration
- Prevents "device not found" errors
- Standard Linux approach

**Cons**:
- May already be loading automatically
- Won't fix other issues
- Requires root access

**When to Use**: Always - this is a prerequisite for ydotoold to work. Should be done regardless of other options.

---

### Option 5: Add Health Check Script with Auto-Restart

**Description**: Create a wrapper script or systemd ExecStartPre/ExecStartPost that checks if ydotoold is healthy and restarts if needed.

**Approach**:
1. Create health check script that:
   - Tests if socket exists and is accessible
   - Tests if `ydotool` commands work
   - Restarts service if health check fails
2. Add to service file:
   - `ExecStartPre=/path/to/health-check.sh` - check before starting
   - `ExecStartPost=/path/to/health-check.sh` - verify after starting
3. Or create separate systemd path unit that monitors socket and restarts service

**Pros**:
- Can detect issues that systemd restart might miss
- Tests actual functionality, not just process existence
- Can provide detailed health status

**Cons**:
- More complex
- Requires writing and maintaining scripts
- May be redundant if systemd restart works
- Adds execution overhead

**When to Use**: If systemd restart policy works but service appears running but isn't functional.

---

### Option 6: Fix Service Dependencies for Wayland

**Description**: Ensure service starts at the right time in Wayland/KDE boot sequence.

**Approach**:
1. Change `After=graphical.target` to `After=display-manager.service` or `After=graphical-session.target`
2. Change `WantedBy=multi-user.target` to `WantedBy=graphical.target`
3. Add `After=systemd-modules-load.service` for uinput module
4. Consider adding `After=dbus.service` if needed
5. Test boot sequence timing

**Pros**:
- Ensures service starts when Wayland is ready
- Prevents timing issues
- Better integration with display manager

**Cons**:
- May not be the issue
- Requires understanding of boot sequence
- May delay service startup unnecessarily

**When to Use**: If logs show service starting before Wayland is ready or if there are timing-related failures.

---

### Option 7: Add Socket Permissions Management

**Description**: Ensure the socket file created by ydotoold has correct permissions and is accessible.

**Approach**:
1. Identify socket location (default: `/tmp/.ydotool_socket` or `/run/ydotool_socket`)
2. Create systemd tmpfiles.d configuration to set socket permissions
3. Or add `ExecStartPost` script that fixes permissions after service starts
4. Ensure user is in `input` group (already done in install script)

**Pros**:
- Fixes permission-related access issues
- Ensures socket is accessible to users
- Prevents "permission denied" errors

**Cons**:
- May not be necessary if permissions are correct
- Socket location may vary
- Requires identifying socket path

**When to Use**: If users report permission errors when using ydotool commands even though daemon is running.

---

### Option 8: Use systemd-run with Better Error Handling

**Description**: Wrap ydotoold execution with systemd-run to get better process management and error handling.

**Approach**:
1. Modify service ExecStart to use `systemd-run` wrapper
2. Add better error handling and logging
3. Configure resource limits if needed
4. Add environment variables if required

**Pros**:
- Better process isolation
- More control over execution
- Can add resource limits

**Cons**:
- Adds complexity
- May not be necessary
- Requires understanding systemd-run

**When to Use**: If standard service approach has issues or if you need special execution environment.

---

### Option 9: Monitor and Alert on Failures

**Description**: Set up monitoring to detect when ydotoold fails and alert the user or log extensively.

**Approach**:
1. Configure systemd service with `OnFailure` to trigger another service
2. Create notification service that sends alert when ydotoold fails
3. Or use systemd journal forwarding to log aggregator
4. Add extensive logging to service file

**Pros**:
- Provides visibility into failures
- Can help diagnose recurring issues
- User knows when service is down

**Cons**:
- Doesn't fix the problem, just reports it
- Adds complexity
- May be noisy if restarts are frequent

**When to Use**: If you want visibility into service health but restart policy handles recovery.

---

### Option 10: Fallback to Manual Start Script

**Description**: Create a fallback mechanism that manually starts ydotoold if systemd service fails.

**Approach**:
1. Create script in `/etc/profile.d/` or `~/.zshrc` that checks if ydotoold is running
2. If not running, attempt to start it
3. Or create cron job that checks and starts if needed
4. Or add to KDE autostart

**Pros**:
- Provides fallback if systemd fails
- Simple to implement
- Can work even if systemd has issues

**Cons**:
- Not as robust as systemd
- May start multiple instances
- Less clean than systemd approach
- Duplicates systemd functionality

**When to Use**: As last resort if systemd service approach completely fails.

---

## Recommended Approach

**Primary Solution**: Combine Option 1 (Enhanced Systemd Service) + Option 4 (uinput Module Loading)

1. **Update service file** with robust restart policy:
   ```ini
   [Unit]
   Description=ydotool daemon
   After=systemd-modules-load.service
   After=graphical.target
   Requires=graphical.target

   [Service]
   Type=simple
   ExecStart=/usr/bin/ydotoold
   Restart=always
   RestartSec=5
   StartLimitIntervalSec=0
   User=root
   Group=input
   StandardOutput=journal
   StandardError=journal

   [Install]
   WantedBy=graphical.target
   ```

2. **Ensure uinput module loads**: Create `/etc/modules-load.d/uinput.conf` with `uinput`

3. **Test and verify**:
   - Reboot system
   - Check service status: `systemctl status ydotoold`
   - Verify it's running: `pgrep ydotoold`
   - Test functionality: `ydotool mousemove --absolute 100 100`

**If Primary Solution Fails**: Consider Option 2 (User Service) as alternative, especially if Wayland requires user-level services.

**Additional Enhancements** (if needed):
- Option 3 (Watchdog Timer) for extra monitoring
- Option 7 (Socket Permissions) if permission issues occur

## Key Configuration Changes

### Service File Improvements
- `Restart=always` - restart even on successful exit (handles crashes)
- `StartLimitIntervalSec=0` - disable restart rate limiting
- `After=systemd-modules-load.service` - ensure uinput module loads first
- `WantedBy=graphical.target` - start with graphical session (Wayland)
- `StandardOutput=journal` and `StandardError=journal` - better logging

### Module Loading
- `/etc/modules-load.d/uinput.conf` - ensures uinput module loads at boot

### Verification Steps
After implementing:
1. Reboot system
2. Check service: `systemctl status ydotoold`
3. Check process: `pgrep ydotoold`
4. Check module: `lsmod | grep uinput`
5. Test functionality: `ydotool mousemove --absolute 100 100`
6. Check logs: `journalctl -u ydotoold -n 50`

## Questions to Consider

1. Does the service start successfully on boot?
2. Does it stay running after boot?
3. Does it restart automatically if it crashes?
4. Are there any error messages in the logs?
5. Is the uinput module loaded?
6. Can users run ydotool commands without errors?
7. Does it work correctly after system sleep/wake?




# Understanding: ydotool Installation and Daemon Service Setup

## Problem Context

This understanding focuses on how to properly install `ydotool` and configure its daemon service (`ydotoold`) to resolve the blocker from Iteration 01. The daemon must be running before `ydotool` commands can function, and proper permissions must be configured for `/dev/uinput` access.

## Current State

- **ydotool binary**: Already installed at `/usr/bin/ydotool` (confirmed in Iteration 01)
- **ydotoold daemon**: Not running (blocker)
- **Permissions**: User not in `input`/`uinput` groups, `/dev/uinput` access denied
- **System**: Linux (Ubuntu/Debian-based), KDE Plasma on Wayland

## ydotool Installation Methods

### Method 1: Package Manager (Recommended for Debian/Ubuntu)

**Command:**
```bash
sudo apt update
sudo apt install ydotool
```

**Pros:**
- Simple and quick
- Handled by package manager (updates, dependencies)
- May include systemd service files

**Cons:**
- May not be available in all distributions
- Version may be older than latest release

**Status**: Already installed via this method (confirmed in Iteration 01)

### Method 2: Build from Source

**Dependencies:**
```bash
sudo apt install cmake make g++ libevdev-dev libudev-dev
```

**Build Steps:**
```bash
git clone https://github.com/ReimuNotMoe/ydotool.git
cd ydotool
mkdir build
cd build
cmake ..
make -j$(nproc)
sudo make install
```

**When to Use:**
- Package not available in repositories
- Need latest version with new features
- Want to customize build options

**Note**: Since `ydotool` is already installed, this method is not needed unless upgrading or troubleshooting.

## ydotool Daemon Service Setup

### Architecture Overview

`ydotool` operates in a client-server architecture:
- **ydotool**: Client command-line tool (sends commands)
- **ydotoold**: Daemon service (receives commands, interacts with kernel via `/dev/uinput`)

The daemon **must be running** before any `ydotool` commands will work. Without the daemon, `ydotool` commands will fail silently or with connection errors.

### Service Management Options

#### Option A: System-Wide Service (Root)

**Setup:**
```bash
# Copy service file if it exists, or create it
sudo cp /usr/lib/systemd/system/ydotool.service /etc/systemd/system/ 2>/dev/null || true

# Reload systemd
sudo systemctl daemon-reload

# Enable and start service
sudo systemctl enable ydotool
sudo systemctl start ydotool
```

**Pros:**
- Runs at system boot
- Available to all users
- Standard Linux service management

**Cons:**
- Requires root privileges
- Runs as root user (security consideration)
- May not be necessary for single-user systems

**Service File Location**: `/etc/systemd/system/ydotool.service` or `/usr/lib/systemd/system/ydotool.service`

#### Option B: User-Specific Service (Recommended for Single User)

**Setup:**
```bash
# Create user systemd directory
mkdir -p ~/.config/systemd/user

# Copy service file if it exists, or create it
cp /usr/lib/systemd/user/ydotool.service ~/.config/systemd/user/ 2>/dev/null || \
  cp /usr/share/systemd/user/ydotool.service ~/.config/systemd/user/ 2>/dev/null || \
  # Create service file manually (see below)

# Reload user systemd
systemctl --user daemon-reload

# Enable and start service
systemctl --user enable ydotool
systemctl --user start ydotool
```

**Pros:**
- No root privileges required (after initial permission setup)
- Runs as regular user
- Starts with user session
- Better security isolation

**Cons:**
- Requires user to be in `input` group or udev rules configured
- Only available to that user
- May not start until user logs in

**Service File Location**: `~/.config/systemd/user/ydotool.service`

**Service File Template** (if not provided by package):
```ini
[Unit]
Description=ydotool daemon
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

### Permission Requirements

#### `/dev/uinput` Access

`ydotoold` requires access to `/dev/uinput` to create virtual input devices. This device typically requires:
- Root privileges, OR
- User in `input` group, OR
- udev rules granting access

#### Method 1: Add User to `input` Group (Recommended)

**Command:**
```bash
sudo usermod -aG input $USER
```

**After adding to group:**
- Log out and log back in, OR
- Run `newgrp input` in current session

**Verify:**
```bash
groups  # Should show 'input' in the list
```

**Pros:**
- Standard Linux approach
- Works system-wide
- Simple to configure

**Cons:**
- Requires sudo access
- Grants broader input device access (security consideration)
- Requires logout/login to take effect

#### Method 2: Configure udev Rules

**Create udev rule file:**
```bash
sudo tee /etc/udev/rules.d/99-ydotool.rules > /dev/null <<EOF
KERNEL=="uinput", MODE="0666", GROUP="input"
EOF
```

**Reload udev:**
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

**Pros:**
- More granular control
- Can be specific to ydotool
- Doesn't require group membership

**Cons:**
- Requires root access
- More complex configuration
- May need device reconnection

**Note**: This method still typically requires the user to be in the `input` group or have the device mode set to allow access.

#### Method 3: Run Daemon as Root (Not Recommended)

**Approach:**
```bash
sudo ydotoold &
```

**Pros:**
- Quick workaround for testing
- Bypasses permission issues immediately

**Cons:**
- Security risk (daemon runs as root)
- Not persistent (stops on logout/reboot)
- Not best practice
- Requires password entry or sudoers configuration

**Recommendation**: Only for temporary testing, not for production use.

## Verification Steps

### 1. Check if ydotool is Installed

```bash
which ydotool
ydotool --version
```

**Expected**: Path to binary (e.g., `/usr/bin/ydotool`) and version number.

### 2. Check if ydotoold Daemon is Running

**For system-wide service:**
```bash
sudo systemctl status ydotoold
# OR
ps aux | grep ydotoold
```

**For user service:**
```bash
systemctl --user status ydotoold
# OR
ps aux | grep ydotoold | grep -v grep
```

**Expected**: Service status showing "active (running)" or process visible in `ps` output.

### 3. Check `/dev/uinput` Permissions

```bash
ls -l /dev/uinput
```

**Expected**: Either owned by root with group `input` and mode `0660`, or mode `0666` allowing all users.

### 4. Test ydotool Functionality

**Test mouse movement:**
```bash
# Absolute movement
ydotool mousemove --absolute -x 100 -y 100

# Relative movement
ydotool mousemove -x 10 -y 10
```

**Test key press:**
```bash
ydotool key 30:1 30:0  # Press and release 'A' key
```

**Expected**: Cursor moves or key is pressed without errors.

**If daemon not running**: Commands will fail with connection errors or hang.

## Service Management Commands

### Start Service

**System-wide:**
```bash
sudo systemctl start ydotoold
```

**User service:**
```bash
systemctl --user start ydotoold
```

### Stop Service

**System-wide:**
```bash
sudo systemctl stop ydotoold
```

**User service:**
```bash
systemctl --user stop ydotoold
```

### Enable Service (Start on Boot/Login)

**System-wide:**
```bash
sudo systemctl enable ydotoold
```

**User service:**
```bash
systemctl --user enable ydotoold
```

### Disable Service

**System-wide:**
```bash
sudo systemctl disable ydotoold
```

**User service:**
```bash
systemctl --user disable ydotoold
```

### Check Service Status

**System-wide:**
```bash
sudo systemctl status ydotoold
```

**User service:**
```bash
systemctl --user status ydotoold
```

### View Service Logs

**System-wide:**
```bash
sudo journalctl -u ydotoold -f
```

**User service:**
```bash
journalctl --user -u ydotoold -f
```

## Troubleshooting Common Issues

### Issue: "Permission denied" when accessing `/dev/uinput`

**Symptoms:**
- Daemon fails to start
- `ydotool` commands fail with permission errors
- Service logs show permission denied errors

**Solutions:**
1. Add user to `input` group: `sudo usermod -aG input $USER` (then logout/login)
2. Check `/dev/uinput` permissions: `ls -l /dev/uinput`
3. Configure udev rules (see Method 2 above)
4. Verify group membership: `groups | grep input`

### Issue: Daemon starts but ydotool commands don't work

**Symptoms:**
- `ydotoold` process is running
- `ydotool` commands fail or hang
- No error messages

**Solutions:**
1. Check daemon is listening: `ps aux | grep ydotoold`
2. Restart daemon: `systemctl --user restart ydotoold`
3. Check service logs for errors: `journalctl --user -u ydotoold`
4. Verify ydotool can connect: `ydotool --version` (should work if daemon is running)

### Issue: Service doesn't start automatically

**Symptoms:**
- Service enabled but doesn't start on login
- Manual start works but doesn't persist

**Solutions:**
1. Verify service is enabled: `systemctl --user is-enabled ydotoold`
2. Check service file location: `~/.config/systemd/user/ydotoold.service`
3. Ensure service file has correct `WantedBy` target (usually `default.target`)
4. Check if user systemd is running: `systemctl --user status`
5. Verify service dependencies are met (e.g., `graphical-session.target`)

### Issue: Service file doesn't exist

**Symptoms:**
- Package installed but no service file found
- Cannot enable/start service

**Solutions:**
1. Check common locations:
   - `/usr/lib/systemd/system/ydotool.service`
   - `/usr/lib/systemd/user/ydotool.service`
   - `/usr/share/systemd/user/ydotool.service`
2. Create service file manually (see template above)
3. Check package contents: `dpkg -L ydotool | grep service`

## Integration with Installation Script

### Current State

The `kde/apply-scripts.sh` script currently:
- Checks for `xdotool` installation
- Attempts to auto-install `xdotool` if missing
- Installs scripts to `~/.local/bin`

### Required Changes

To support `ydotool` instead of `xdotool`, the script should:

1. **Check for ydotool installation:**
   ```bash
   if ! command -v ydotool &> /dev/null; then
       # Install ydotool
   fi
   ```

2. **Check/add user to input group:**
   ```bash
   if ! groups | grep -q input; then
       echo "Adding user to input group..."
       sudo usermod -aG input $USER
       echo "Please log out and back in for group changes to take effect."
   fi
   ```

3. **Create/verify systemd user service:**
   ```bash
   mkdir -p ~/.config/systemd/user
   # Create or copy service file
   systemctl --user daemon-reload
   systemctl --user enable ydotoold
   systemctl --user start ydotoold
   ```

4. **Verify daemon is running:**
   ```bash
   if ! systemctl --user is-active --quiet ydotoold; then
       echo "Warning: ydotoold daemon is not running"
       echo "Attempting to start..."
       systemctl --user start ydotoold
   fi
   ```

## Recommended Setup Flow

Based on the research and current state, the recommended setup flow is:

1. **Install ydotool** (if not already installed):
   ```bash
   sudo apt update && sudo apt install ydotool
   ```

2. **Add user to input group:**
   ```bash
   sudo usermod -aG input $USER
   ```
   Then logout and login again.

3. **Create systemd user service:**
   ```bash
   mkdir -p ~/.config/systemd/user
   # Create service file (see template above)
   systemctl --user daemon-reload
   systemctl --user enable ydotoold
   systemctl --user start ydotoold
   ```

4. **Verify setup:**
   ```bash
   systemctl --user status ydotoold
   ydotool mousemove --absolute -x 100 -y 100
   ```

## Key Takeaways

1. **ydotool requires ydotoold daemon**: The daemon must be running before any `ydotool` commands will work.

2. **Permission requirements**: Access to `/dev/uinput` is required, typically achieved by adding user to `input` group.

3. **Service management**: Systemd user service is recommended for single-user systems, providing automatic startup and proper lifecycle management.

4. **Verification is critical**: Always verify daemon is running and test `ydotool` commands before proceeding with script modifications.

5. **Installation script integration**: The `apply-scripts.sh` script should handle daemon setup automatically, similar to how it currently handles `xdotool` installation.

## Open Questions

1. **Does the ydotool package include a systemd service file?**
   - Need to check: `dpkg -L ydotool | grep service`
   - If not, we'll need to create one manually

2. **What is the exact service name?**
   - Is it `ydotoold.service` or `ydotool.service`?
   - Need to verify actual package contents

3. **Should the installation script require logout/login after adding to input group?**
   - Can we detect if group membership is active?
   - Should we warn user or fail gracefully?

4. **What happens if user doesn't have sudo access?**
   - Can we fall back to manual instructions?
   - Should we support udev rules as alternative?

5. **How should we handle service file creation?**
   - Check if package provides one first?
   - Create our own if missing?
   - What if user already has custom service file?

## Next Steps

1. Verify ydotool package contents (service files, binaries)
2. Test adding user to input group and verify permissions
3. Create/verify systemd user service file
4. Test daemon startup and ydotool functionality
5. Integrate setup steps into `apply-scripts.sh`
6. Document manual setup process as fallback






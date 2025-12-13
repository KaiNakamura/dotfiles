# Concepts: Fixing ydotool Daemon Not Running Issue

## Problem Context

The `ydotoold` daemon service is failing to start because the installation script (`ydotool/install.sh`) only installs the `ydotool` CLI package but not the `ydotoold` daemon package. The service file references `/usr/bin/ydotoold`, but this executable doesn't exist because the package wasn't installed.

**Current State**:
- ✅ `ydotool` CLI package installed (`/usr/bin/ydotool` exists)
- ✅ User is in `input` group
- ✅ Systemd service file exists and is enabled
- ❌ `ydotoold` daemon package NOT installed (`/usr/bin/ydotoold` missing)
- ❌ Service fails with exit code 203/EXEC (executable not found)

**Goal**: Fix the installation script and verify that `ydotool` can successfully run (daemon running, mouse movement works).

## Solution Concepts

### Concept 1: Simple Package Addition ⭐ **RECOMMENDED**

**Description**: Update the installation script to install both `ydotool` and `ydotoold` packages in a single command.

**Implementation**:
- Modify `ydotool/install.sh` line 11:
  - Change: `sudo apt install -y ydotool`
  - To: `sudo apt install -y ydotool ydotoold`
- No other changes needed
- Service should start automatically after package installation

**Pros**:
- ✅ Minimal change (one line)
- ✅ Simple and straightforward
- ✅ Follows standard package installation pattern
- ✅ Service is already configured correctly
- ✅ No additional complexity

**Cons**:
- ⚠️ Requires re-running installation script or manual package install
- ⚠️ User needs to verify service starts correctly

**Verification Steps**:
1. Run updated installation script
2. Check `/usr/bin/ydotoold` exists: `ls -l /usr/bin/ydotoold`
3. Check service status: `systemctl status ydotoold`
4. Verify daemon is running: `pgrep -x ydotoold`
5. Test mouse movement: `ydotool mousemove --absolute 100 100`

---

### Concept 2: Separate Package Installation with Verification

**Description**: Install packages separately with explicit verification steps between installations.

**Implementation**:
- Install `ydotool` package
- Verify `ydotool` CLI exists
- Install `ydotoold` package
- Verify `ydotoold` executable exists
- Then proceed with service setup

**Pros**:
- ✅ More explicit verification at each step
- ✅ Better error messages if one package fails
- ✅ Easier to debug which package installation failed
- ✅ Can verify each component independently

**Cons**:
- ⚠️ More verbose script
- ⚠️ Slightly slower (two separate apt calls)
- ⚠️ May be overkill for simple package installation

**Example Implementation**:
```bash
# Install ydotool CLI
sudo apt install -y ydotool
if ! command -v ydotool &> /dev/null; then
    echo "ERROR: ydotool CLI installation failed"
    exit 1
fi

# Install ydotoold daemon
sudo apt install -y ydotoold
if [ ! -f /usr/bin/ydotoold ]; then
    echo "ERROR: ydotoold daemon installation failed"
    exit 1
fi
```

---

### Concept 3: Installation Script with Idempotent Checks

**Description**: Add checks to verify packages are installed before attempting installation, making the script idempotent.

**Implementation**:
- Check if `ydotool` is installed before installing
- Check if `ydotoold` is installed before installing
- Skip installation if already present
- Always verify executables exist after installation

**Pros**:
- ✅ Safe to run multiple times
- ✅ Faster on subsequent runs (skips if already installed)
- ✅ Better user experience (no unnecessary operations)
- ✅ More robust error handling

**Cons**:
- ⚠️ More complex script logic
- ⚠️ May mask issues if packages are partially installed
- ⚠️ More code to maintain

**Example Implementation**:
```bash
# Check and install ydotool CLI
if ! command -v ydotool &> /dev/null; then
    sudo apt install -y ydotool
fi

# Check and install ydotoold daemon
if [ ! -f /usr/bin/ydotoold ]; then
    sudo apt install -y ydotoold
fi

# Verify both are installed
if ! command -v ydotool &> /dev/null || [ ! -f /usr/bin/ydotoold ]; then
    echo "ERROR: Package installation incomplete"
    exit 1
fi
```

---

### Concept 4: Manual Fix + Verification Script

**Description**: Provide manual fix instructions and create a separate verification script instead of modifying installation script immediately.

**Implementation**:
- Document manual fix: `sudo apt install -y ydotoold`
- Create/update `ydotool-test.sh` to verify daemon is running
- Test verification script works
- Then update installation script in next step

**Pros**:
- ✅ Quick path to unblock verification
- ✅ Can test verification approach before committing to installation script
- ✅ Separates concerns (fix vs verification)
- ✅ Allows immediate testing

**Cons**:
- ⚠️ Temporary solution (still need to fix installation script)
- ⚠️ Two-step process
- ⚠️ Manual intervention required

**Use Case**: Good for immediate testing, but Concept 1 should follow

---

### Concept 5: Enhanced Installation Script with Service Verification

**Description**: Combine Concept 1 with explicit service status verification and better error messages.

**Implementation**:
- Install both packages (as in Concept 1)
- After service start, verify it's actually running
- Provide clear error messages if service fails
- Check service status and report to user

**Pros**:
- ✅ Fixes the root cause (missing package)
- ✅ Provides immediate feedback on service status
- ✅ Better user experience with clear status messages
- ✅ Catches issues early

**Cons**:
- ⚠️ Slightly more complex than Concept 1
- ⚠️ Service verification may be redundant (systemctl already reports status)

**Example Implementation**:
```bash
# Install both packages
sudo apt install -y ydotool ydotoold

# Verify executables exist
if [ ! -f /usr/bin/ydotool ] || [ ! -f /usr/bin/ydotoold ]; then
    echo "ERROR: Package installation failed"
    exit 1
fi

# Start service and verify
sudo systemctl start ydotoold
sleep 1  # Give service time to start
if ! systemctl is-active --quiet ydotoold; then
    echo "WARNING: Service started but is not active"
    systemctl status ydotoold
    exit 1
fi
```

---

## Recommendation Summary

**Primary Recommendation**: **Concept 1 (Simple Package Addition)** - This is the most straightforward fix:
1. Minimal change required (one line)
2. Addresses root cause directly
3. Service configuration is already correct
4. Can verify manually after fix

**Secondary Recommendation**: **Concept 5 (Enhanced with Verification)** - If you want better error handling and immediate feedback, but Concept 1 is sufficient for this iteration's goal.

**Not Recommended for This Iteration**:
- **Concept 2**: Overkill for simple package installation
- **Concept 3**: Adds complexity not needed for this fix
- **Concept 4**: Temporary solution, should fix root cause instead

## Decision Points

1. **Which concept to use?** - Concept 1 (simple) or Concept 5 (with verification)?
2. **Verification approach?** - Use existing `ydotool-test.sh` or enhance it?
3. **Error handling level?** - Minimal (Concept 1) or comprehensive (Concept 5)?

## Verification Plan (After Fix)

Once the installation script is fixed and `ydotoold` package is installed:

1. **Install missing package**: Run updated installation script or `sudo apt install -y ydotoold`
2. **Verify executable exists**: `ls -l /usr/bin/ydotoold`
3. **Check service status**: `systemctl status ydotoold` should show `active (running)`
4. **Verify daemon process**: `pgrep -x ydotoold` should return PID
5. **Test mouse movement**: 
   - `ydotool mousemove --absolute 100 100` (absolute coordinates)
   - `ydotool mousemove 10 10` (relative movement)
6. **Run test script**: `./ydotool-test.sh` should pass all checks

## Success Criteria

- [ ] `ydotoold` package is installed
- [ ] `/usr/bin/ydotoold` executable exists
- [ ] `ydotoold` service is running (`systemctl status ydotoold` shows active)
- [ ] `ydotool mousemove --absolute` works correctly
- [ ] `ydotool mousemove` (relative) works correctly
- [ ] `ydotool-test.sh` passes all checks
- [ ] No permission or connection errors

## Notes

- This iteration focuses ONLY on verifying `ydotool` can run
- Script modifications (replacing xdotool) will come in later iterations
- The fix is straightforward - just need to install the missing package
- Service is already properly configured, just needs the executable to exist





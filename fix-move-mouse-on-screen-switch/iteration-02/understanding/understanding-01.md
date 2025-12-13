# Understanding

## Problem Summary

KDE keyboard shortcut scripts that center the mouse cursor after window switching (Meta+HJKL) or moving windows to different screens (Meta+Shift+HJKL) stopped working after switching to Wayland. The scripts currently rely on `xdotool`, which is X11-specific and incompatible with Wayland's security model.

## Current Implementation State

### Script Architecture

The scripts follow a two-tier architecture:

1. **Action Scripts** (`kwin-switch-*.sh`, `kwin-move-screen-*.sh`):
   - Execute KWin actions via `qdbus` calls to `org.kde.kglobalaccel`
   - Call the helper script `kwin-center-cursor.sh` after the action completes
   - These scripts appear to still work correctly (the `qdbus` calls are Wayland-compatible)

2. **Helper Script** (`kwin-center-cursor.sh`):
   - Currently uses `xdotool` for all operations:
     - `xdotool getactivewindow` - Gets active window ID
     - `xdotool getwindowgeometry --shell` - Gets window position and size
     - `xdotool mousemove` - Moves cursor to calculated center
   - This is the component that fails on Wayland

### Installation Script (`apply-scripts.sh`)

- Checks for `xdotool` installation and attempts to install it if missing
- Installs scripts to `~/.local/bin/`
- Creates desktop files for keyboard shortcuts
- Registers shortcuts in `kglobalshortcutsrc` via `kwriteconfig5`
- Currently assumes X11 environment (checks for `xdotool`)

## Previous Iteration Context

### Iteration 01: Initial ydotool Integration Plan

**Status**: Blocked at Phase 1.2 verification

**Approach**: Implement Option 1 from concepts - replace `xdotool` with `ydotool` for cursor movement, using `qdbus` to query KWin for window information.

**Key Findings**:
- `ydotool` is installed at `/usr/bin/ydotool`
- `ydotoold` daemon is **not running** (required for `ydotool` to function)
- Permission issues: `/dev/uinput` requires root or proper group membership
- User not in `input`/`uinput` groups
- Cannot test mouse movement without daemon running

**Blocker**: Phase 1.2 verification cannot be completed without resolving daemon setup and permissions. The plan assumed `ydotool` was ready to test, but daemon configuration needs to happen before verification can proceed.

**Key Learnings**:
- `ydotool` requires `ydotoold` daemon to be running
- Daemon needs access to `/dev/uinput` (typically requires root or udev rules)
- Verification phase should come after daemon setup, not before
- Need to determine daemon management approach (systemd service vs manual start)

## Current Iteration (02) Goals

1. **Resolve daemon setup**: Get `ydotoold` running and accessible
2. **Complete Phase 1.2 verification**: Test `ydotool mousemove` functionality once daemon is running
3. **Proceed with implementation**: Continue with script modifications once verification is complete

## Root Cause Analysis

### Why xdotool Doesn't Work on Wayland

Wayland has a fundamentally different security model than X11:
- Does not expose a global window list to applications
- Does not allow arbitrary cursor manipulation by applications
- Isolates applications from each other for security

`xdotool` relies on X11 APIs that don't exist in Wayland:
- `getactivewindow` - Cannot query windows on Wayland
- `getwindowgeometry` - Cannot get geometry on Wayland
- `mousemove` - Cannot move cursor on Wayland

### What Still Works

- The `qdbus` calls to invoke KWin shortcuts (`org.kde.kglobalaccel /component/kwin invokeShortcut`) work on Wayland
- The window switching/moving actions themselves function correctly
- Only the cursor centering functionality is broken

## Proposed Solution Approach

Based on concepts and plan documents, the chosen approach is **Option 1: qdbus + ydotool Hybrid**:

1. **Replace window queries**: Use `qdbus` to query KWin for:
   - Active window ID: `qdbus org.kde.KWin /KWin org.kde.KWin.activeWindow`
   - Window geometry: Method TBD (needs research in Phase 1.1)

2. **Replace cursor movement**: Use `ydotool` for cursor movement:
   - Absolute movement: `ydotool mousemove --absolute -x <x> -y <y>`

3. **Update installation script**: Modify `apply-scripts.sh` to:
   - Check for `ydotool` instead of `xdotool`
   - Ensure `ydotoold` daemon is running
   - Handle daemon startup/configuration

## Current Blockers

1. **ydotoold Daemon Not Running**
   - Required for `ydotool` to function
   - Needs to be started before testing can proceed
   - Options: systemd user service, manual start, or on-demand check

2. **Permission Issues**
   - `/dev/uinput` requires root or proper group membership
   - User not currently in `input`/`uinput` groups
   - May need udev rules or group membership

3. **KWin D-Bus Method Research Needed**
   - Exact method for getting window geometry via `qdbus` needs to be identified
   - Phase 1.1 of the plan requires research into KWin D-Bus API

## Scripts Affected

1. **`kde/scripts/kwin-center-cursor.sh`** - Major changes needed:
   - Replace all `xdotool` calls with `qdbus` + `ydotool`
   - Adapt to new command syntax and output parsing

2. **`kde/apply-scripts.sh`** - Dependency check updates:
   - Replace `xdotool` check with `ydotool` check
   - Add `ydotoold` daemon check/startup logic

3. **Action scripts** (`kwin-switch-*.sh`, `kwin-move-screen-*.sh`) - Should not need changes:
   - Already use `qdbus` for KWin actions
   - Only call the helper script, which will be updated

## Open Questions

1. **Daemon Management**: How should `ydotoold` be managed?
   - Systemd user service (recommended in plan)?
   - Manual start script?
   - Check and start on-demand in `apply-scripts.sh`?

2. **Permissions**: How should `/dev/uinput` access be handled?
   - Add user to `input`/`uinput` groups?
   - Configure udev rules?
   - Require sudo for daemon startup?

3. **KWin D-Bus Methods**: What are the exact `qdbus` commands for:
   - Getting active window ID (likely `org.kde.KWin.activeWindow`)
   - Getting window geometry (method TBD - needs research)

4. **X11 Compatibility**: Is backward compatibility with X11 needed?
   - Current plan assumes Wayland-only
   - Could add detection logic if X11 support is required

5. **Error Handling**: How should errors be handled?
   - Silent fail (current behavior)?
   - Log to file?
   - Show notifications?

6. **Auto-Installation**: Should `apply-scripts.sh` auto-install `ydotool`?
   - Currently auto-installs `xdotool`
   - Should it do the same for `ydotool`?

## Next Steps (Based on Plan)

1. **Phase 1.1**: Research KWin D-Bus methods for window geometry
2. **Phase 2.2**: Set up `ydotoold` daemon (systemd service or manual)
3. **Phase 2.3**: Resolve permissions for `/dev/uinput` access
4. **Phase 1.2**: Complete verification of `ydotool` capabilities (once daemon is running)
5. **Phase 3**: Modify scripts to use `qdbus` + `ydotool`
6. **Phase 4**: Test and validate functionality

## Follow-up Questions for Clarification

1. Do you have `sudo` access to start `ydotoold` daemon, or would you prefer a user-level solution?
2. Would you prefer systemd user service for `ydotoold`, or manual start/on-demand checking?
3. Is backward compatibility with X11 needed, or is Wayland-only acceptable?
4. How should errors be handled - silent fail, logging, or notifications?
5. Should `apply-scripts.sh` attempt to auto-install `ydotool`, or just check and warn?
6. Have you tested whether the window switching/moving actions themselves still work correctly on Wayland (just without cursor movement)?






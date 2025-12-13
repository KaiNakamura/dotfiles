# Understanding: ydotool Viability Assessment

## Problem Context

The KDE scripts (`kde/scripts/kwin-center-cursor.sh` and related scripts) that move the mouse cursor when using keybinds like Meta+HJKL and Meta+Shift+HJKL stopped working after switching to Wayland. These scripts currently use `xdotool`, which is X11-specific and incompatible with Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh`
- Gets active window ID using `xdotool getactivewindow`
- Gets window geometry (X, Y, WIDTH, HEIGHT) using `xdotool getwindowgeometry`
- Calculates center coordinates: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`
- Moves cursor to center using `xdotool mousemove`

This script is called by multiple other scripts (`kwin-switch-*.sh`, `kwin-move-screen-*.sh`) after window switching/moving operations.

## Current ydotool Status

### Installation Status
- **Version**: `ydotool 0.1.8-3build1` (Ubuntu/Debian package)
- **Infrastructure**: Fully set up through iterations 01-05:
  - `ydotool` and `ydotoold` packages installed
  - Systemd service (`ydotoold.service`) configured and running
  - User added to `input` group
  - Udev rule (`99-uinput.rules`) configured for `/dev/uinput` permissions
  - Socket permissions (`/tmp/.ydotool_socket`) fixed
  - Basic mouse movement functionality confirmed working

### Coordinate Bug Issue

**Observed Behavior**:
- `ydotool mousemove <x> <y>` commands execute successfully
- Mouse cursor moves, but **always goes to top-left corner** regardless of specified coordinates
- Tested with various coordinate values:
  - Small coordinates (10, 10)
  - Monitor centers (960, 540; 2880, 540; 1851, 1680)
  - Large coordinates (1920, 1080)
  - All result in mouse moving to top-left corner

**Known Bug**: GitHub Issue #250 documents this exact problem
- Issue is still **open/unresolved**
- Affects absolute coordinate positioning on Wayland
- Root cause: Wayland's security model restricts direct control over input devices via `uinput`

### Workarounds Tested (Iteration 06)

All tested workarounds failed:
1. **Moving to (0,0) first, then target coordinates**: Still goes to top-left
2. **Adding delays between commands**: No effect
3. **Different coordinate ranges**: All values result in same behavior
4. **Relative movement**: Version 0.1.8 doesn't support `--relative` flag or relative movement syntax

**Test Scripts Created**:
- `ydotool-test.sh`: Basic functionality test
- `ydotool-coordinate-test.sh`: Comprehensive coordinate testing
- `ydotool-relative-test.sh`: Relative movement workaround attempts

### Version Considerations

**Current Version**: `0.1.8-3build1` (Ubuntu/Debian package)
- No relative movement support
- Absolute coordinates broken on Wayland
- No command-line flags to work around the issue

**Potential Solutions from Research**:
- Some users report success with building from latest source (may have fixes)
- Minecraft mods mention scaling factors, but this appears to be for game-specific coordinate systems
- No reliable workarounds found for general-purpose cursor positioning

## Alternatives Research

### 1. KWin D-Bus API
- **Window Geometry**: Already using `qdbus` to query KWin for window information
- **Cursor Control**: Need to investigate if KWin D-Bus provides cursor movement methods
- **Advantage**: Native Wayland/KDE integration, no external dependencies
- **Unknown**: Whether cursor control is exposed via D-Bus

### 2. KWin Scripting (JavaScript API)
- KWin provides a JavaScript scripting API for window management
- **Unknown**: Whether cursor positioning is available in scripting API
- **Advantage**: Native integration, can be bundled with window operations
- **Consideration**: Requires learning KWin scripting API

### 3. Custom uinput Solutions
- Could build custom tool using `uinput` directly
- **Challenge**: Same underlying limitation - Wayland restricts uinput absolute positioning
- **Consideration**: May face same coordinate issues as ydotool

### 4. Hybrid Approach
- Use KWin D-Bus for window geometry (already working)
- Use alternative method for cursor movement
- **Advantage**: Separates concerns, can swap cursor movement method independently

### 5. Other Tools
- **wtype**: Keyboard automation tool, unclear if it supports mouse
- **wlr-randr**: Display management, not cursor control
- **swaymsg** (Sway-specific): Not applicable to KDE

## Key Questions to Answer

1. **Is ydotool viable?**
   - Current version (0.1.8) has fundamental coordinate bug on Wayland
   - No working workarounds found
   - Issue #250 remains open
   - **Assessment**: Not viable with current version for absolute positioning

2. **Are there ways around the coordinate issue?**
   - Tested workarounds all failed
   - Relative movement not supported in this version
   - Building from source may have fixes, but unverified
   - **Assessment**: No reliable workarounds found

3. **Should we consider alternatives?**
   - Yes, ydotool appears fundamentally limited for this use case
   - KWin D-Bus/scripting APIs may provide native solution
   - Need to investigate KWin capabilities before abandoning ydotool entirely
   - **Assessment**: Alternatives should be explored

## Next Steps for Investigation

1. **Verify ydotool status**: Check if building from latest source resolves coordinate issue
2. **Research KWin D-Bus**: Investigate if cursor control methods exist
3. **Research KWin Scripting**: Check JavaScript API documentation for cursor capabilities
4. **Test alternatives**: Evaluate other tools or approaches
5. **Decision point**: Determine if ydotool path should be abandoned or if fixes exist

## Understanding Summary

ydotool has been successfully set up and can move the mouse cursor, but it cannot reliably position the cursor to specific coordinates on Wayland. The coordinate bug is a known issue (GitHub #250) that remains unresolved. All tested workarounds have failed. The tool appears fundamentally limited for absolute cursor positioning on Wayland due to Wayland's security model restricting uinput-based absolute positioning.

**Recommendation**: Investigate KWin-native solutions (D-Bus API or scripting) as alternatives, as they would be better integrated with the Wayland/KDE environment and may avoid the uinput limitations that affect ydotool.



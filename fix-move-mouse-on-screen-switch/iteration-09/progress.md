# Progress: Iteration 09

## Problem Context

KDE scripts for mouse cursor movement (used with keybinds like Meta+HJKL and Meta+Shift+HJKL) no longer work after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh` - centers cursor on active window

**Current Implementation** (X11):
- Uses `xdotool getactivewindow` to get window ID
- Uses `xdotool getwindowgeometry` to get window position/size
- Uses `xdotool mousemove` to move cursor

## Previous Iteration Summary

**Iterations 01-05**: Set up ydotool infrastructure and got basic mouse movement working, but discovered coordinate accuracy bug.

**Iteration 06**: Tested various workarounds for ydotool coordinate bug - all failed with version 0.1.8.

**Iteration 07**: Investigated KWin JavaScript scripting API - `workspace.cursorPos` assignment doesn't move cursor.

**Iteration 08**: Upgraded to ydotool v1.0.4 from GitHub releases:
- Bug persists even in v1.0.4 (absolute coordinates still broken)
- Disabled mouse acceleration (not the root cause)
- **Discovered working workaround**: Move to (0,0) with absolute, then use relative movement to target
- Workaround has brief visual flash to top-left but achieves correct positioning

## Current Status

**Working Solution Found**: Relative movement workaround successfully positions cursor correctly:
1. Move to (0,0) using `ydotool mousemove --absolute -x 0 -y 0` (this works - goes to top-left)
2. Move relatively to target using `ydotool mousemove -x <target_x> -y <target_y>`

**Workaround Characteristics**:
- ✅ Achieves correct cursor positioning
- ✅ Works across multi-monitor setup
- ⚠️ Brief visual flash to top-left corner before correcting (acceptable tradeoff)

**Current Setup**:
- ydotool v1.0.4 installed from GitHub releases
- `ydotoold` daemon running with socket at `/tmp/.ydotool_socket`
- `YDOTOOL_SOCKET` environment variable configured
- Mouse acceleration disabled
- Workaround script created: `ydotool/workaround-relative.sh`

## Current Iteration Goals

1. **Implement Workaround in kwin-center-cursor.sh**: Update script to use ydotool with relative movement workaround
2. **Update Script Syntax**: Use v1.0.4 syntax (`--absolute -x -y` flags)
3. **Test Integration**: Verify script works correctly with KDE window switching/moving scripts
4. **Handle Edge Cases**: Ensure script handles multi-monitor scenarios correctly
5. **Documentation**: Update script comments and README if needed

## Next Steps

- Modify `kde/scripts/kwin-center-cursor.sh` to use ydotool instead of xdotool
- Implement two-step movement (absolute to 0,0 then relative to target)
- Test with all 8 related scripts (kwin-switch-*.sh and kwin-move-screen-*.sh)
- Verify cursor centers correctly on active window across all monitors
- Ensure workaround is reliable and acceptable for daily use


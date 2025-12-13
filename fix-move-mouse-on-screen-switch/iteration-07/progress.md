# Progress: Iteration 07

## Problem Context

KDE scripts for mouse cursor movement (used with keybinds like Meta+HJKL and Meta+Shift+HJKL) no longer work after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh` - centers cursor on active window

**Current Implementation** (X11):
- Uses `xdotool getactivewindow` to get window ID
- Uses `xdotool getwindowgeometry` to get window position/size
- Uses `xdotool mousemove` to move cursor

## Previous Iteration Summary

**Iterations 01-05**: Set up ydotool infrastructure and got basic mouse movement working, but discovered coordinate accuracy bug.

**Iteration 06**: Tested various workarounds for ydotool coordinate bug:
- Tested different coordinate values across all monitors
- Investigated GitHub issue #250 (same bug, still open)
- Tried workarounds: moving to 0,0 first, delays, different coordinate ranges
- **Result**: All approaches failed - mouse always moves to top-left corner

## Current Issue

ydotool cannot reliably move the cursor to specific coordinates on Wayland. This is a fundamental limitation of the tool that cannot be worked around with command-line options or timing tricks.

**Confirmed Limitations**:
- Absolute coordinates don't work (always goes to top-left)
- No relative movement support in this version
- No command-line workarounds available
- GitHub issue #250 documents this but remains unresolved

**Impact**:
ydotool cannot be used for the actual use case. Need to explore alternative approaches that don't rely on ydotool for cursor positioning.

## Current Iteration Goals

1. **Explore KWin D-Bus API**: Investigate if KWin provides methods to control cursor position directly
2. **Research KWin Scripting**: Check if KWin JavaScript API can move cursor
3. **Consider Custom Solutions**: Evaluate custom uinput-based tools or other alternatives
4. **Hybrid Approach**: Use KWin D-Bus for window geometry + alternative for cursor movement
5. **Find Working Solution**: Identify and implement a method that can reliably move cursor to calculated coordinates

## Next Steps

- Research KWin D-Bus cursor control methods
- Check KWin scripting API documentation for cursor movement capabilities
- Investigate alternative tools (wtype, custom uinput solutions)
- Test if KWin can be used directly for cursor positioning
- Determine best approach for Wayland-compatible cursor movement



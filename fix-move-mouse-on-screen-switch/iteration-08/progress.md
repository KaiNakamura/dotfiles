# Progress: Iteration 08

## Problem Context

KDE scripts for mouse cursor movement (used with keybinds like Meta+HJKL and Meta+Shift+HJKL) no longer work after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh` - centers cursor on active window

**Current Implementation** (X11):
- Uses `xdotool getactivewindow` to get window ID
- Uses `xdotool getwindowgeometry` to get window position/size
- Uses `xdotool mousemove` to move cursor

## Previous Iteration Summary

**Iterations 01-05**: Set up ydotool infrastructure and got basic mouse movement working, but discovered coordinate accuracy bug.

**Iteration 06**: Tested various workarounds for ydotool coordinate bug - all failed. Mouse always moves to top-left corner regardless of coordinates.

**Iteration 07**: Investigated KWin JavaScript scripting API:
- Successfully accessed scripting console and loaded scripts via D-Bus
- Tested `workspace.cursorPos = Qt.point(x, y)` assignment
- **Result**: Scripts execute without errors but cursor does not move
- API appears to be read-only or non-functional for cursor movement in Wayland

## Current Issue

KWin scripting API's `workspace.cursorPos` property assignment doesn't actually move the cursor. Scripts execute successfully (confirmed via logs showing "Executing script" and runtime), but cursor remains stationary. This suggests the API either:
- Is read-only (assignment silently fails)
- Doesn't support cursor movement in Wayland sessions
- Requires different method or approach

**Confirmed Limitations**:
- `workspace.cursorPos` assignment executes but doesn't move cursor
- No error messages - assignment appears to succeed silently
- Multiple syntax variations tested (direct assignment, property modification) - none work
- Interactive console testing confirms cursor doesn't move

**Impact**:
KWin scripting API cannot be used for cursor movement. Need to explore alternative KWin D-Bus methods, investigate other APIs, or consider different approaches entirely.

## Current Iteration Goals

1. **Investigate KWin D-Bus Cursor Methods**: Check if KWin exposes cursor control via D-Bus (not scripting)
2. **Research KWin Effects API**: Explore if KWin effects can control cursor position
3. **Check Alternative APIs**: Investigate other KWin interfaces that might support cursor movement
4. **Consider libei/wlr-randr**: Evaluate newer Wayland protocols for input control
5. **Evaluate Custom Solutions**: Consider custom uinput-based tools or other low-level approaches
6. **Find Working Solution**: Identify and implement a method that can reliably move cursor to calculated coordinates on Wayland

## Next Steps

- Research KWin D-Bus cursor control methods (non-scripting)
- Check KWin effects API documentation
- Investigate libei or wlr-randr protocols
- Explore custom uinput-based solutions
- Test alternative KWin interfaces for cursor control
- Determine if any Wayland-compatible solution exists for programmatic cursor movement



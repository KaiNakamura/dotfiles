# Progress: Iteration 02

## Problem Context

KDE scripts for mouse cursor movement (used with keybinds like Meta+HJKL and Meta+Shift+HJKL) no longer work after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh` - centers cursor on active window

**Current Implementation** (X11):
- Uses `xdotool getactivewindow` to get window ID
- Uses `xdotool getwindowgeometry` to get window position/size
- Uses `xdotool mousemove` to move cursor

## Previous Iteration Summary

**Iteration 01** attempted to implement ydotool integration but was blocked at Phase 1.2 verification:
- `ydotool` is installed but `ydotoold` daemon not running
- Permission issues with `/dev/uinput` access
- Verification cannot proceed without daemon setup

**Key Insight**: Daemon configuration needs to happen before verification. The plan's phase ordering needs adjustment.

## Current Iteration Goals

1. **Resolve daemon setup**: Get `ydotoold` running and accessible
2. **Complete Phase 1.2 verification**: Test `ydotool mousemove` functionality
3. **Proceed with implementation**: Continue with script modifications once verification is complete

## Next Steps

- Set up `ydotoold` daemon (systemd service or manual start)
- Verify `ydotool` mouse movement works
- Continue with KWin D-Bus method research (Phase 1.1)
- Modify `kwin-center-cursor.sh` script
- Update `apply-scripts.sh` installation script






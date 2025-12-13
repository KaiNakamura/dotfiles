# Progress: Iteration 06

## Problem Context

KDE scripts for mouse cursor movement (used with keybinds like Meta+HJKL and Meta+Shift+HJKL) no longer work after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh` - centers cursor on active window

**Current Implementation** (X11):
- Uses `xdotool getactivewindow` to get window ID
- Uses `xdotool getwindowgeometry` to get window position/size
- Uses `xdotool mousemove` to move cursor

## Previous Iteration Summary

**Iteration 01** attempted to implement ydotool integration but was blocked at daemon/permissions setup.

**Iteration 02** completed the installation infrastructure (ydotool package, systemd service).

**Iteration 03** fixed missing `ydotoold` package installation.

**Iteration 04** implemented enhanced systemd service but encountered compatibility issues.

**Iteration 05** successfully got basic mouse movement working:
- Created udev rule for `/dev/uinput` permissions
- Fixed socket permissions (`/tmp/.ydotool_socket`)
- Updated service file to automatically set socket permissions
- Fixed test script syntax
- **Result**: Mouse movement works, but coordinates are incorrect

## Current Issue

After getting `ydotool-test.sh` working in iteration 05, we discovered that while mouse movement is functional, **the coordinates are incorrect**. The mouse consistently moves to the top-left corner of the top-leftmost monitor regardless of the coordinates specified in the command.

**Observed Behavior**:
- `ydotool mousemove 100 100` → mouse moves to top-left corner
- `ydotool mousemove 500 500` → mouse moves to top-left corner
- `ydotool mousemove 1920 1080` → mouse moves to top-left corner

This is a known bug with ydotool on Wayland where absolute coordinates don't work correctly. The mouse moves, but always to the same fixed location (top-left) instead of the specified coordinates.

**Impact**:
This prevents ydotool from being used for the actual use case - centering the cursor on the active window. The KDE scripts need to:
1. Get window geometry (position and size)
2. Calculate center coordinates
3. Move mouse to those coordinates

If ydotool can't move to specific coordinates, it won't work for this purpose.

## Current Iteration Goals

1. **Investigate coordinate issue**: Research why absolute coordinates don't work and potential workarounds
2. **Test relative movement**: Check if relative movement (`ydotool mousemove --relative` or similar) works correctly
3. **Explore alternatives**: Investigate if there are workarounds (e.g., move to 0,0 then relative movement)
4. **Test multi-monitor behavior**: Understand how coordinates work across multiple monitors
5. **Find solution**: Either fix the coordinate issue or find an alternative approach that works

## Next Steps

- Research ydotool Wayland coordinate bug and known workarounds
- Test relative movement commands if available
- Investigate if there's a way to query current mouse position
- Check if there are alternative tools or approaches for Wayland cursor movement
- Test coordinate behavior with different monitor configurations
- Determine if we can work around the bug or need an alternative solution



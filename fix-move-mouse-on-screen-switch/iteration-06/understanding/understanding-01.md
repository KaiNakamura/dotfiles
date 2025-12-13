# Understanding: Iteration 06

## Problem Statement

KDE keyboard shortcut scripts that center the mouse cursor after window switching/moving operations no longer work after switching from X11 to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't function on Wayland.

**Affected Scripts:**
- `kde/scripts/kwin-center-cursor.sh` - Main helper script that centers cursor on active window
- `kde/scripts/kwin-switch-{left,right,up,down}.sh` - Window switching scripts that call the center script
- `kde/scripts/kwin-move-screen-{left,right,up,down}.sh` - Window moving scripts that call the center script

## Current Implementation (X11-based)

The core script `kwin-center-cursor.sh` currently:
1. Uses `xdotool getactivewindow` to get the active window ID
2. Uses `xdotool getwindowgeometry --shell` to get window position (X, Y) and dimensions (WIDTH, HEIGHT)
3. Calculates center coordinates: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`
4. Uses `xdotool mousemove` to move the cursor to the calculated center

**Dependencies:**
- All window operations rely on `xdotool` which queries X11 window manager
- No Wayland-compatible alternative currently implemented

## Previous Iteration Progress

**Iterations 01-05** focused on setting up `ydotool` as a Wayland-compatible replacement for `xdotool`:

1. **Installation Infrastructure** (Iterations 01-04):
   - Created `ydotool/` package in dotfiles with installation script
   - Set up systemd service (`ydotoold.service`) for daemon
   - Configured udev rules for `/dev/uinput` permissions (`99-uinput.rules`)
   - Fixed socket permissions (`/tmp/.ydotool_socket`)
   - Installed both `ydotool` (CLI) and `ydotoold` (daemon) packages

2. **Basic Functionality** (Iteration 05):
   - Successfully got mouse movement working
   - Created test script `ydotool-test.sh` to verify functionality
   - **Critical Issue Discovered**: Absolute coordinates don't work correctly - mouse always moves to top-left corner regardless of specified coordinates

## Current Blocker: ydotool Coordinate Bug

**Observed Behavior:**
- `ydotool mousemove 100 100` → mouse moves to top-left corner
- `ydotool mousemove 500 500` → mouse moves to top-left corner  
- `ydotool mousemove 1920 1080` → mouse moves to top-left corner

**Impact:**
This is a known bug with ydotool on Wayland where absolute coordinates don't work correctly. The mouse moves (proving ydotool is functional), but always to a fixed location (top-left) instead of the specified coordinates. This prevents ydotool from being used for the actual use case - centering the cursor on the active window, which requires precise coordinate targeting.

## Codebase Context

**Key Files:**
- `kde/scripts/kwin-center-cursor.sh` - Target script needing Wayland compatibility
- `kde/scripts/kwin-switch-*.sh` - Window switching scripts (4 files)
- `kde/scripts/kwin-move-screen-*.sh` - Window moving scripts (4 files)
- `ydotool/install.sh` - Installation script (installs ydotool + ydotoold)
- `ydotool/ydotoold.service` - Systemd service file for daemon
- `ydotool/99-uinput.rules` - Udev rule for device permissions
- `ydotool-test.sh` - Test script demonstrating coordinate issue

**Existing Infrastructure:**
- Scripts already use `qdbus` to invoke KWin shortcuts (e.g., `qdbus org.kde.kglobalaccel /component/kwin invokeShortcut`)
- Codebase has Wayland detection logic in `kde/apply-kksrc.sh` (checks `$XDG_SESSION_TYPE`)
- ydotool is installed and daemon is running (verified in iteration 05)

## What Needs to Be Done

1. **Investigate Coordinate Issue:**
   - Research why absolute coordinates fail on Wayland
   - Test if relative movement (`ydotool mousemove --relative` or similar) works correctly
   - Explore workarounds (e.g., move to 0,0 then use relative movement)
   - Understand multi-monitor coordinate behavior

2. **Window Information Querying:**
   - Replace `xdotool getactivewindow` with Wayland-compatible method
   - Replace `xdotool getwindowgeometry` with Wayland-compatible method
   - Options identified in concepts: use `qdbus` to query KWin D-Bus API for window information

3. **Script Modification:**
   - Update `kwin-center-cursor.sh` to:
     - Detect Wayland vs X11 session
     - Use appropriate tooling for each environment
     - Query window geometry via KWin D-Bus (Wayland) or xdotool (X11)
     - Move cursor using ydotool (Wayland) or xdotool (X11)

## Open Questions

1. **Coordinate Workaround:**
   - Can relative movement be used as a workaround for the absolute coordinate bug?
   - Is there a way to query current mouse position to calculate relative movement?
   - Are there alternative tools or approaches for Wayland cursor movement?

2. **KWin D-Bus API:**
   - What are the exact `qdbus` commands to get active window ID?
   - What are the exact `qdbus` commands to get window geometry (X, Y, WIDTH, HEIGHT)?
   - How do coordinates work across multiple monitors on Wayland?

3. **Implementation Approach:**
   - Should we implement hybrid X11/Wayland detection or Wayland-only?
   - What's the best way to handle coordinate system differences between X11 and Wayland?

## Success Criteria

The solution should:
- Successfully center the mouse cursor on the active window after window switching/moving operations
- Work correctly on Wayland (primary target)
- Optionally maintain X11 compatibility (if hybrid approach chosen)
- Handle multi-monitor setups correctly
- Be reliable and maintainable



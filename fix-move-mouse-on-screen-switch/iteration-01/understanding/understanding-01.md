# Understanding

## Problem Summary

KDE keyboard shortcut scripts that were designed to move the mouse cursor to the center of windows after switching focus (Meta+HJKL) or moving windows to different screens (Meta+Shift+HJKL) no longer work after switching to Wayland.

## Current Implementation Analysis

### Script Architecture

The scripts follow a consistent pattern:

1. **Action scripts** (`kwin-switch-*.sh`, `kwin-move-screen-*.sh`) - Execute KWin actions via `qdbus` and call the helper script
2. **Helper script** (`kwin-center-cursor.sh`) - Centers the cursor on the active window using `xdotool`

### Key Scripts

- `kwin-switch-{left,right,up,down}.sh` - Switch window focus in a direction, then center cursor
- `kwin-move-screen-{left,right,up,down}.sh` - Move window to another screen, then center cursor
- `kwin-center-cursor.sh` - Shared helper that performs the actual cursor movement

### How the Helper Works (`kwin-center-cursor.sh`)

1. Waits 10ms for focus/position to settle
2. Gets the active window ID using `xdotool getactivewindow`
3. Gets window geometry (X, Y, WIDTH, HEIGHT) using `xdotool getwindowgeometry --shell`
4. Calculates center coordinates: `CENTER_X = X + WIDTH/2`, `CENTER_Y = Y + HEIGHT/2`
5. Moves the mouse cursor using `xdotool mousemove`

### Keybinding Setup

- Scripts are installed to `~/.local/bin/`
- Desktop files are created in `~/.local/share/applications/`
- Shortcuts are registered in `kglobalshortcutsrc` via `kwriteconfig5`
- The install script checks for `xdotool` and installs it if missing

## Root Cause

The scripts rely entirely on **xdotool**, which is an **X11-only tool**. xdotool interacts with the X Window System to:
- Query window information (`getactivewindow`, `getwindowgeometry`)
- Manipulate the mouse cursor (`mousemove`)

On Wayland, these X11 APIs are not available. Wayland has a fundamentally different security model that:
- Does not expose a global window list to applications
- Does not allow arbitrary cursor manipulation by applications
- Isolates applications from each other for security

This is why the mouse movement stopped working after switching to Wayland.

## Components That Still Work

- The `qdbus` calls to invoke KWin shortcuts should still work on Wayland
- The window switching/moving actions themselves likely still function
- Only the cursor centering functionality is broken

## Components That Are Broken

- `xdotool getactivewindow` - Cannot query windows on Wayland
- `xdotool getwindowgeometry` - Cannot get geometry on Wayland  
- `xdotool mousemove` - Cannot move cursor on Wayland

## Follow-up Questions

1. Is the window switching itself (Meta+HJKL invoking KWin shortcuts) still working correctly, just without the mouse movement?
2. Are you using pure Wayland, or XWayland for compatibility?
3. Have you noticed any error output when running the scripts manually from a terminal?
4. Would you be open to installing additional tools (like `ydotool` or using KWin scripting) if needed for Wayland compatibility?






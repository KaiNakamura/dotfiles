# Plan: Implement Wayland Mouse Cursor Movement

## Overview

Replace `xdotool` usage in KDE scripts with Wayland-compatible alternatives (`qdbus` + `ydotool`) to restore mouse cursor centering functionality after window switching/moving.

**Target Script**: `kde/scripts/kwin-center-cursor.sh`

**Approach**: Concept 1 (ydotool + qdbus) - Use `qdbus` to query KWin D-Bus for window information, then use `ydotool` to move the cursor.

## Current State

- ✅ Installation infrastructure complete (`ydotool` package, `ydotoold` daemon service)
- ⏳ Verification pending (daemon status, ydotool functionality, permissions)
- ⏳ Script modifications pending (replace xdotool calls)

## High-Level Plan

### Phase 1: Verification & Research
**Goal**: Ensure foundation is solid before building on top of it

1. **Verify ydotool Setup**
   - Check `ydotoold` daemon status
   - Verify user group membership (`input` group)
   - Test basic ydotool mouse movement commands
   - Understand coordinate system behavior

2. **Research KWin D-Bus Methods**
   - Find method to get active window ID
   - Find method to get window geometry (X, Y, WIDTH, HEIGHT)
   - Understand output format and parsing requirements
   - Test D-Bus queries manually

### Phase 2: Script Modification
**Goal**: Replace xdotool calls with qdbus + ydotool

1. **Modify `kwin-center-cursor.sh`**
   - Replace `xdotool getactivewindow` → `qdbus` query for active window
   - Replace `xdotool getwindowgeometry` → `qdbus` query for window geometry
   - Replace `xdotool mousemove` → `ydotool mousemove --absolute`
   - Handle coordinate calculations (window center calculation)
   - Add error handling for missing tools/daemon

2. **Update Dependencies**
   - Modify `kde/apply-scripts.sh` to check for `ydotool` instead of `xdotool`
   - Update any dependency checks or error messages

### Phase 3: Testing & Validation
**Goal**: Ensure script works correctly in various scenarios

1. **Basic Functionality**
   - Test cursor centering on active window
   - Verify coordinates are correct
   - Test with different window sizes/positions

2. **Edge Cases**
   - Multi-monitor setups (if applicable)
   - Fullscreen windows
   - Windows at screen edges
   - Error handling when daemon not running

## Open Questions for User

1. **Verification Priority**: Should we complete Phase 1 verification first, or proceed directly to script modification assuming ydotool works?

2. **Error Handling Level**: Do you want robust error handling from the start (check daemon status, graceful failures), or keep it simple initially?

3. **Multi-Monitor Support**: How important is proper multi-monitor coordinate handling? Should we prioritize this or handle single-monitor first?

4. **Testing Approach**: Do you want to test incrementally (after each change) or modify everything then test?

5. **Coordinate System**: Do you know if ydotool uses screen-absolute coordinates or window-relative? This affects how we calculate the center point.

## Next Steps

Waiting for user input to refine the plan and fill in specifics before proceeding to implementation.





# Understanding: ydotool Coordinate Scaling Issue and Current State

## Problem Statement

The KDE scripts for mouse cursor movement (used with keybinds like Meta+HJKL and Meta+Shift+HJKL) no longer work after switching to Wayland. The scripts have been updated to use `ydotool` instead of `xdotool`, but there's a systematic coordinate system mismatch preventing accurate cursor positioning.

## Current Implementation State

### Architecture

The solution uses a **shared library pattern** to eliminate code duplication:

- **`kde/scripts/kwin-screen-helpers.sh`**: Shared helper functions library containing:
  - `get_current_screen()`: Gets active screen via qdbus
  - `parse_all_screen_geometries()`: Parses kscreen-doctor output (handles ANSI color codes)
  - `get_screen_geometry()`: Retrieves geometry for specific screen
  - `find_neighbor_screen()`: Finds closest neighbor screen with overlap prioritization
  - `move_cursor_to_coordinates()`: **Core function** that moves cursor using ydotool workaround

- **Four direction scripts** (`kwin-move-screen-{left,right,up,down}.sh`):
  - Each script follows the same pattern:
    1. Parse screen geometries
    2. Get current screen
    3. Find neighbor screen in specified direction
    4. Execute KWin shortcut to move window
    5. Calculate center coordinates of target screen
    6. Call `move_cursor_to_coordinates()` to center cursor

### Current Workaround Implementation

The `move_cursor_to_coordinates()` function (lines 186-198 in `kwin-screen-helpers.sh`) implements a two-step workaround:

```bash
move_cursor_to_coordinates() {
    local target_x=$1  # KWin global coordinate (e.g., 960)
    local target_y=$2  # KWin global coordinate (e.g., 540)
    
    export YDOTOOL_SOCKET=/tmp/.ydotool_socket
    
    # Step 1: Move to origin (0,0) using absolute
    ydotool mousemove --absolute -x 0 -y 0 2>/dev/null
    sleep 0.05  # Small delay to ensure movement completes
    
    # Step 2: Move relatively from (0,0) to target
    ydotool mousemove -x "$target_x" -y "$target_y" 2>/dev/null
}
```

**Why this workaround exists**: ydotool has a known bug where absolute coordinates don't work correctly on Wayland (moves to top-left corner regardless of specified coordinates). The workaround uses absolute movement to (0,0) (which works), then relative movement to the target.

## The Coordinate Scaling Problem

### Discovery

User testing has confirmed that ydotool's relative movement coordinate system uses **exactly 0.5x scaling** compared to KWin's global coordinate system:

| Target Location | KWin Global Coordinate | ydotool Relative Value | Scaling Factor |
|----------------|------------------------|------------------------|----------------|
| Left monitor center (DP-5) | (960, 540) | (480, 270) | 0.5x |
| Right monitor center (HDMI-A-1) | (2880, 540) | (1440, 270) | 0.5x |
| Top edge between monitors | (1920, 0) | (960, 0) | 0.5x |
| Bottom monitor center (eDP-1) | ~(1851, 1680) | (960, 810) | ~0.5x |

**Key Observation**: The scaling factor is **consistently exactly 0.5x** (half scale) across all tested coordinates and screens, affecting both X and Y axes equally.

### Current Behavior

When `move_cursor_to_coordinates(960, 540)` is called:
1. Cursor moves to (0,0) correctly ✓
2. Relative movement of (960, 540) is sent to ydotool
3. **Problem**: ydotool interprets this as half-scale, so cursor ends up at approximately (480, 270) instead of (960, 540) ✗

### What Should Happen

The function should divide coordinates by 2 before passing to ydotool:
```bash
ydotool mousemove -x $((target_x / 2)) -y $((target_y / 2))
```

This would convert KWin coordinates (960, 540) to ydotool coordinates (480, 270), resulting in correct cursor positioning.

## System Configuration Context

### Display Setup
- **Three monitors**:
  - DP-5 (left): Geometry 0,0 1920×1080, Scale: 1
  - HDMI-A-1 (right): Geometry 1920,0 1920×1080, Scale: 1
  - eDP-1 (bottom): Geometry 975,1080 1920×1200, Scale: 1
- All monitors show `Scale: 1` in kscreen-doctor output
- Laptop screen native resolution: 3072×1920
- Laptop screen current resolution: 1920×1200 (1.6x scaling)

### Technical Stack
- **Session**: Wayland (KWin compositor, reports Xwayland operation mode)
- **ydotool Version**: v1.0.4 (upgraded from apt package 0.1.8)
- **ydotoold**: Running as systemd service with proper permissions
- **Mouse acceleration**: Disabled (`XLbInptPointerAcceleration=0`)

## Root Cause Investigation Status

### Iteration 11 Findings

A systematic investigation was conducted to understand why ydotool uses 0.5x scaling:

**System Information Gathered**:
- Confirmed native resolution: 3072×1920 (not 2x as initially thought)
- Current resolution: 1920×1200 (1.6x scaling)
- KWin running in Xwayland operation mode despite Wayland session
- uinput device: "ydotoold virtual device" at `/dev/input/event16`
- No explicit resolution properties found in uinput device sysfs

**Hypotheses Developed**:
1. **Leading**: uinput device has implicit 2x resolution causing 0.5x scaling when relative movements are interpreted
2. **Alternative**: Wayland compositor transformation applied to uinput devices
3. **Alternative**: libinput coordinate mapping differences
4. **Alternative**: Xwayland mode affecting coordinate interpretation

**Investigation Artifacts Created**:
- Test scripts for coordinate behavior
- Hypothesis documentation
- System information gathering

### Current Understanding

The **exact root cause is still unknown**, but the following is established:

1. **Scaling is systematic**: Exactly 0.5x (not approximate) - suggests a 2x resolution mismatch somewhere
2. **Global effect**: Affects all screens uniformly, indicating device-level or compositor-level property
3. **Consistent behavior**: Works the same way regardless of starting position or target screen
4. **Not display scaling**: All monitors report Scale: 1, so not related to KDE display scaling settings

## Current Iteration Status

### Decision Point

Iteration 12 is at a decision point:

1. **Option A**: Implement the fix now (divide coordinates by 2) and validate it works
   - Pros: Immediate solution, straightforward implementation
   - Cons: Root cause unknown, may not be portable across systems

2. **Option B**: Continue investigation to understand root cause
   - Pros: Better understanding for portability and maintainability
   - Cons: May not find definitive answer, delays solution

### Implementation Requirements (if proceeding with fix)

If implementing the fix, the following changes are needed:

1. **Modify `move_cursor_to_coordinates()`** in `kwin-screen-helpers.sh`:
   - Divide `target_x` and `target_y` by 2 before passing to ydotool
   - Add comments explaining why division is necessary
   - Use integer division (bash arithmetic: `$((target_x / 2))`)

2. **Testing Requirements**:
   - Test all four direction scripts (left, right, up, down)
   - Verify cursor centers correctly on all three screens
   - Test edge cases (screens at boundaries, different monitor configurations)

3. **Documentation**:
   - Document the coordinate scaling issue and workaround
   - Note that root cause is unknown
   - Explain why division by 2 is necessary

## Key Questions for Clarification

1. **Approach**: Should we implement the fix now (divide by 2) or continue investigating the root cause?

2. **Portability**: How important is it to understand the root cause for portability across different systems? Should we add detection logic for the scaling factor, or hardcode 0.5x?

3. **Validation**: What testing approach should we use to validate the fix works correctly across all scenarios?

4. **Edge Cases**: Are there any specific scenarios or configurations we should test beyond the basic four-direction screen switching?

## Summary

**Problem**: ydotool's relative movement uses exactly 0.5x scaling compared to KWin's global coordinates, causing cursor to land at incorrect positions.

**Current State**: 
- Infrastructure is complete (ydotool installed, scripts implemented, workaround in place)
- Coordinate scaling issue identified and quantified (exactly 0.5x)
- Root cause investigation conducted but not definitively resolved

**Solution**: Divide coordinates by 2 before passing to ydotool's relative movement command.

**Open Question**: Whether to implement fix now or continue investigating root cause for better portability and understanding.


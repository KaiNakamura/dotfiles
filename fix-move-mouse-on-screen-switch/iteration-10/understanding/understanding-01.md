# Understanding: ydotool Relative Movement Coordinate Issue

## Problem Context

The KDE screen switching scripts (`kwin-move-screen-*.sh`) have been updated to use `ydotool` instead of `xdotool` for Wayland compatibility. The scripts successfully execute and move the cursor, but there's a coordinate accuracy issue preventing the cursor from reaching the intended target location.

## Current Implementation

### Architecture

1. **Shared Library Pattern**: `kde/scripts/kwin-screen-helpers.sh` contains reusable helper functions:
   - `get_current_screen()` - Gets active screen name via KWin D-Bus
   - `parse_all_screen_geometries()` - Parses `kscreen-doctor` output into associative array
   - `get_screen_geometry()` - Retrieves geometry for specific screen
   - `find_neighbor_screen()` - Finds closest neighbor screen with overlap prioritization
   - `move_cursor_to_coordinates()` - **Core function with the issue**

2. **Direction Scripts**: Four scripts (`kwin-move-screen-{left,right,up,down}.sh`) follow the same pattern:
   - Parse screen geometries
   - Get current screen
   - Find neighbor screen in specified direction
   - Execute KWin shortcut to move window
   - Calculate center coordinates of target screen
   - Call `move_cursor_to_coordinates()` with center coordinates

### Coordinate Calculation

The scripts calculate screen centers using global coordinate system:
- **DP-5** (leftmost): X=0, Y=0, 1920×1080 → center: (960, 540)
- **HDMI-A-1** (right): X=1920, Y=0, 1920×1080 → center: (2880, 540)
- **eDP-1** (bottom): X=891, Y=1080, 1920×1200 → center: (1851, 1680)

These are **global coordinates** representing the center of each screen in the multi-monitor layout.

### Current Workaround Implementation

The `move_cursor_to_coordinates()` function (lines 186-198 in `kwin-screen-helpers.sh`) implements a workaround for ydotool's absolute coordinate bug:

```bash
move_cursor_to_coordinates() {
    local target_x=$1  # e.g., 960 (global coordinate)
    local target_y=$2  # e.g., 540 (global coordinate)
    
    # Step 1: Move to origin (0,0) using absolute
    ydotool mousemove --absolute -x 0 -y 0
    sleep 0.05
    
    # Step 2: Move relatively from (0,0) to target
    ydotool mousemove -x "$target_x" -y "$target_y"
}
```

**The Problem**: This function treats the target coordinates as **relative movement values** after moving to (0,0). However, the target coordinates are **absolute global coordinates**, not relative deltas.

## The Issue

### Observed Behavior

**Critical Correction**: The issue is NOT about small vs large movements. **ALL coordinates are wrong** - the movement is consistent and predictable, but the coordinate system does not align with the actual screen sizes of the monitors.

1. **Consistent but incorrect**: All relative movements are consistently wrong - they don't align with the screen geometry
2. **Systematic offset**: The coordinate system appears to use a different scale or reference frame than KWin's global coordinates
3. **Specific coordinate works**: User discovered that (475, 275) correctly centers on leftmost screen (DP-5), which suggests there's a scaling factor or transformation

### Root Cause Hypothesis

The core issue is a **coordinate system mismatch** between:
- **KWin's global coordinate system**: Used by `kscreen-doctor` and screen geometry calculations (e.g., DP-5 center at 960, 540)
- **ydotool's coordinate system**: Used after moving to (0,0) with absolute coordinates

After moving to (0,0) using absolute coordinates, ydotool's relative movement coordinate system appears to:
1. **Use a different scale**: Possibly scaled by a factor (e.g., 0.5x, 2x, or some DPI-related scaling)
2. **Use a different reference frame**: Might be screen-local instead of global, or use a different origin
3. **Apply a transformation**: There might be a systematic transformation (scaling + offset) between the two coordinate systems

The fact that (475, 275) works for the leftmost screen (which should be at 960, 540) suggests:
- **Scaling factor**: 475/960 ≈ 0.495, 275/540 ≈ 0.509 - approximately 0.5x scaling?
- **Or different reference**: The coordinate system might be screen-local (relative to current screen) rather than global

## Key Questions to Investigate

1. **What is ydotool's coordinate system after moving to (0,0)?**
   - Is it screen-local (relative to the screen containing 0,0) or global?
   - What scale does it use? Is there a DPI scaling factor?
   - Does it match the physical pixel coordinates or use logical coordinates?

2. **What is the transformation between coordinate systems?**
   - What scaling factor converts KWin global coordinates to ydotool coordinates?
   - Is there an offset in addition to scaling?
   - Can we derive a formula: `ydotool_coord = f(kwin_coord)`?

3. **Why does (475, 275) work for (960, 540)?**
   - Is there a consistent scaling factor (e.g., ~0.5x)?
   - Does this scaling apply to all coordinates?
   - Can we test other screens to verify the scaling factor?

4. **How should the function work?**
   - Should we apply a scaling factor to convert KWin coordinates to ydotool coordinates?
   - Should we query the current cursor position and calculate relative movement from there?
   - Should we use a different approach that doesn't rely on coordinate conversion?

## Technical Details

### ydotool Version
- Using ydotool v1.0.4 (upgraded from apt package 0.1.8 in iteration 08)
- Syntax: `ydotool mousemove --absolute -x <x> -y <y>` for absolute
- Syntax: `ydotool mousemove -x <delta_x> -y <delta_y>` for relative
- Socket: `/tmp/.ydotool_socket` (configured via `YDOTOOL_SOCKET` env var)

### Known Limitations
- Absolute coordinates don't work correctly (moves to top-left) - this is why the workaround exists
- Mouse acceleration was disabled (`XLbInptPointerAcceleration=0`) but issue persists
- The workaround (absolute to 0,0 then relative) was discovered in iteration 08

## Next Steps for Investigation

1. **Map the coordinate transformation**:
   - Test multiple known coordinates to establish the relationship
   - Try (960, 540) → should map to (475, 275) based on observation
   - Try (2880, 540) → see where it actually goes, calculate scaling
   - Try (1851, 1680) → verify if scaling is consistent across all screens
   - Derive the transformation formula: `ydotool_coord = scale_factor * kwin_coord` (or more complex)

2. **Understand the coordinate system**:
   - Verify if relative movements after (0,0) are screen-local or global
   - Check if there's DPI scaling involved
   - Test if the coordinate system changes based on which screen contains (0,0)

3. **Test the scaling hypothesis**:
   - If (475, 275) works for (960, 540), scaling ≈ 0.495
   - Apply this scaling to other screen centers and test
   - Verify if scaling is consistent across X and Y axes

4. **Explore alternative approaches**:
   - Query current cursor position and calculate true relative movement
   - Use a calibration approach: test a few points and derive transformation
   - Investigate if there's a way to get ydotool's coordinate system directly

## Summary

The core issue is a **systematic coordinate system mismatch**. The `move_cursor_to_coordinates()` function treats KWin's global coordinates as if they directly map to ydotool's relative movement coordinate system, but they don't.

**Key Insight**: ALL coordinates are wrong, not just large ones. The movement is consistent and predictable, indicating a systematic transformation issue rather than a threshold or bug.

**The Problem**: After moving to (0,0) using absolute coordinates, ydotool's relative movement uses a different coordinate system than KWin's global coordinates. The coordinate systems don't align - there's likely a scaling factor (approximately 0.5x based on the (475, 275) → (960, 540) observation) or a different reference frame.

**The Solution Path**: We need to:
1. Understand ydotool's coordinate system after moving to (0,0)
2. Derive the transformation formula between KWin coordinates and ydotool coordinates
3. Apply this transformation in `move_cursor_to_coordinates()` to convert KWin global coordinates to ydotool relative movement values

The fact that (475, 275) correctly centers on the leftmost screen (which should be at 960, 540) suggests a scaling factor of approximately 0.5x, but this needs to be verified across all screens and directions.


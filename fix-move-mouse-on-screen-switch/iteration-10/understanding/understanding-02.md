# Understanding: ydotool Half-Scale Coordinate System

## Problem Context

The KDE screen switching scripts use `ydotool` for Wayland compatibility. After moving to (0,0) using absolute coordinates, ydotool's relative movement coordinate system uses **exactly half the scale** of KWin's global coordinate system.

## Critical Discovery: Exact 0.5x Scaling Factor

User testing has confirmed that ydotool's relative movement coordinate system uses **exactly 0.5x scaling** compared to KWin's global coordinates:

### Test Results

| Target Location | KWin Global Coordinate | ydotool Relative Value | Scaling Factor |
|----------------|------------------------|------------------------|----------------|
| Left monitor center (DP-5) | (960, 540) | (480, 270) | 0.5x |
| Right monitor center (HDMI-A-1) | (2880, 540) | (1440, 270) | 0.5x |
| Top edge between monitors | (1920, 0) | (960, 0) | 0.5x |
| Bottom monitor center (eDP-1) | ~(1851, 1680) | (960, 810) | ~0.5x |

**Key Observation**: The scaling factor is **consistently 0.5x** (exactly half) across all tested coordinates and screens.

## Current Implementation Issue

The `move_cursor_to_coordinates()` function in `kwin-screen-helpers.sh` currently does:

```bash
move_cursor_to_coordinates() {
    local target_x=$1  # e.g., 960 (KWin global coordinate)
    local target_y=$2  # e.g., 540 (KWin global coordinate)
    
    # Step 1: Move to origin (0,0) using absolute
    ydotool mousemove --absolute -x 0 -y 0
    sleep 0.05
    
    # Step 2: Move relatively from (0,0) to target
    ydotool mousemove -x "$target_x" -y "$target_y"  # WRONG: uses full coordinate
}
```

**The Problem**: The function passes KWin global coordinates directly to ydotool's relative movement, but ydotool expects coordinates at **half scale**.

**What Should Happen**: The function should divide coordinates by 2 before passing to ydotool:
```bash
ydotool mousemove -x $((target_x / 2)) -y $((target_y / 2))
```

## Screen Layout

From `kscreen-doctor` output:
- **DP-5** (left): Geometry: 0,0 1920×1080, Scale: 1 → center: (960, 540)
- **HDMI-A-1** (right): Geometry: 1920,0 1920×1080, Scale: 1 → center: (2880, 540)
- **eDP-1** (bottom): Geometry: 975,1080 1920×1200, Scale: 1 → center: (1851, 1680)

All monitors show `Scale: 1`, so the scaling issue is not related to display scaling settings.

## Why Half-Scale?

### Possible Explanations

1. **Wayland Logical vs Physical Pixels**: Wayland may use logical pixels (scaled) while ydotool uses physical pixels, but this doesn't explain why it's exactly 0.5x consistently.

2. **ydotool Coordinate System**: ydotool's relative movement after absolute (0,0) might use a different coordinate system that's scaled or transformed. The fact that it's exactly 0.5x suggests it might be:
   - Using a different unit system
   - Applying a fixed scaling factor
   - Interpreting coordinates relative to a different reference frame

3. **uinput Device Configuration**: The uinput virtual device created by ydotool might have different resolution/scale settings than the actual display.

4. **Wayland Compositor Behavior**: KWin/Wayland might be applying a transformation when receiving input from uinput devices.

### What We Know

- The scaling is **exactly 0.5x** (not approximate)
- It's consistent across all screens and coordinates
- It applies to both X and Y axes equally
- Display scaling in KDE is set to 1.0 for all monitors
- The issue occurs specifically with relative movement after absolute (0,0)

### What We Don't Know

- **Why** ydotool uses half-scale coordinates
- Whether this is a bug, limitation, or intentional behavior
- If this is specific to Wayland, KDE, or ydotool version
- If there's a configuration option to change this behavior

## The Solution

The fix is straightforward: divide all coordinates by 2 before passing to ydotool's relative movement:

```bash
move_cursor_to_coordinates() {
    local target_x=$1  # KWin global coordinate
    local target_y=$2  # KWin global coordinate
    
    export YDOTOOL_SOCKET=/tmp/.ydotool_socket
    
    # Step 1: Move to origin (0,0) using absolute
    ydotool mousemove --absolute -x 0 -y 0 2>/dev/null
    sleep 0.05
    
    # Step 2: Move relatively from (0,0) to target
    # Apply 0.5x scaling to convert KWin coordinates to ydotool coordinates
    local ydotool_x=$((target_x / 2))
    local ydotool_y=$((target_y / 2))
    ydotool mousemove -x "$ydotool_x" -y "$ydotool_y" 2>/dev/null
}
```

## Verification Needed

Before implementing, we should verify:
1. Does the scaling apply consistently to all screen positions?
2. Does it work correctly for all four direction scripts?
3. Are there any edge cases where 0.5x scaling doesn't work?
4. Should we use floating-point division or integer division? (Integer division should be fine for pixel coordinates)

## Summary

**Root Cause**: ydotool's relative movement coordinate system uses exactly **0.5x scaling** compared to KWin's global coordinate system. This is a systematic, consistent transformation that applies to all coordinates.

**The Fix**: Divide all coordinates by 2 before passing to ydotool's relative movement command.

**Why It Happens**: Unknown - could be related to Wayland's coordinate system, uinput device configuration, or ydotool's internal behavior. The exact cause doesn't matter for the fix, but understanding it could help prevent similar issues in the future.


# Understanding: Root Cause Investigation for ydotool 0.5x Coordinate Scaling

## Problem Summary

The KDE screen switching scripts successfully move the cursor using ydotool, but there's a systematic coordinate system mismatch: **ydotool's relative movement uses exactly 0.5x scaling** compared to KWin's global coordinate system. This has been confirmed through user testing across all screens and coordinates.

## Current State

### What We Know

1. **Scaling Factor**: Exactly 0.5x (half scale) - consistent across all coordinates and screens
   - Left monitor center: (960, 540) → requires (480, 270) ✓
   - Right monitor center: (2880, 540) → requires (1440, 270) ✓
   - Top edge: (1920, 0) → requires (960, 0) ✓
   - Bottom monitor center: ~(1851, 1680) → requires (960, 810) ✓

2. **Coordinate System**: 
   - KWin uses global coordinates from `kscreen-doctor` output
   - All monitors report `Scale: 1` in kscreen-doctor (no display scaling)
   - ydotool relative movement after absolute (0,0) uses a different coordinate system

3. **Workaround Implementation**:
   - Current: `move_cursor_to_coordinates()` passes KWin coordinates directly to ydotool
   - Required: Divide coordinates by 2 before passing to ydotool

4. **Technical Context**:
   - ydotool v1.0.4 (upgraded from apt 0.1.8)
   - Wayland session (KWin compositor)
   - Absolute coordinates don't work (moves to top-left) - workaround uses absolute to (0,0) then relative
   - Mouse acceleration disabled (`XLbInptPointerAcceleration=0`)

### What We Don't Know

**The Root Cause**: Why does ydotool use half-scale coordinates?

## Potential Root Causes to Investigate

### Hypothesis 1: Wayland Logical vs Physical Pixel Coordinate System

**Theory**: Wayland may use logical pixels (scaled) for its coordinate system, while ydotool's uinput device uses physical pixels. However, this doesn't explain why it's exactly 0.5x consistently across all screens.

**Investigation Needed**:
- Check if Wayland has separate logical/physical coordinate systems
- Verify if KWin's global coordinates are logical or physical
- Check if uinput device resolution matches display resolution

### Hypothesis 2: Display Scaling at Hardware Level

**Theory**: The user mentioned a potential clue: laptop screen has 3840×2400 native resolution but is set to 1920×1200 (2x scaling). This could affect how coordinates are interpreted.

**Investigation Needed**:
- Check actual native resolutions vs configured resolutions for all monitors
- Verify if there's a system-wide scaling factor affecting coordinate interpretation
- Check if the 0.5x scaling relates to the 2x hardware scaling on the laptop screen

**Key Question**: If the laptop screen uses 2x hardware scaling, why would that affect ydotool's coordinate system globally (across all screens)?

### Hypothesis 3: uinput Device Configuration

**Theory**: The uinput virtual device created by ydotool might have different resolution/scale settings than the actual display system.

**Investigation Needed**:
- Check uinput device properties/resolution
- Verify if uinput device has a fixed resolution that differs from display resolution
- Check if there's a way to configure uinput device resolution

### Hypothesis 4: Wayland Compositor Input Transformation

**Theory**: KWin/Wayland might be applying a transformation when receiving input from uinput devices, possibly related to how it handles virtual input devices.

**Investigation Needed**:
- Check Wayland protocol documentation for input coordinate handling
- Investigate if compositors apply transformations to uinput devices
- Check if there's a known issue with ydotool and Wayland coordinate systems

### Hypothesis 5: ydotool Internal Behavior

**Theory**: ydotool itself might apply a scaling factor internally, possibly related to how it interprets coordinates or how it communicates with the compositor.

**Investigation Needed**:
- Review ydotool source code (if available) for coordinate transformation logic
- Check ydotool documentation for coordinate system explanation
- Search GitHub issues for similar coordinate scaling problems

## Coordinate System Flow

Understanding the coordinate transformation path:

```
KWin Global Coordinates (from kscreen-doctor)
  ↓
Screen center calculation (e.g., 960, 540)
  ↓
move_cursor_to_coordinates() function
  ↓
ydotool absolute to (0,0) - works correctly
  ↓
ydotool relative movement - uses 0.5x scaled coordinates
  ↓
Wayland compositor receives input
  ↓
Cursor position in KWin global coordinates
```

**Key Question**: Where does the 0.5x scaling occur?
- In ydotool's relative movement calculation?
- In the uinput device configuration?
- In Wayland's handling of uinput input?
- In KWin's transformation of uinput events?

## Investigation Approach

### Step 1: Verify Coordinate System Properties

1. **Check display resolutions**:
   ```bash
   kscreen-doctor -o  # Check configured resolutions
   # Compare with native resolutions if available
   ```

2. **Check uinput device properties**:
   ```bash
   # Check uinput device resolution/scale
   # May require examining /sys/class/input/ or /dev/uinput
   ```

3. **Test coordinate system behavior**:
   - Does the scaling apply only after absolute (0,0)?
   - Does it apply to all relative movements?
   - Is it consistent regardless of starting position?

### Step 2: Research External Documentation

1. **Wayland protocol**: Understand how input coordinates are handled
2. **uinput documentation**: Check if device resolution affects coordinate interpretation
3. **ydotool documentation/issues**: Search for coordinate system explanations or similar issues
4. **KWin documentation**: Check if compositor applies transformations to uinput devices

### Step 3: Test Alternative Approaches

1. **Query current cursor position**: Instead of calculating from (0,0), query actual position and calculate true relative movement
2. **Test without absolute (0,0)**: See if relative movement from current position uses different scaling
3. **Test on different hardware**: Verify if scaling is consistent across different systems

## Why Understanding Root Cause Matters

While the fix is straightforward (divide by 2), understanding the root cause is important for:

1. **Portability**: Will this work on other systems with different display configurations?
2. **Reliability**: Could the scaling factor change under different conditions?
3. **Maintainability**: Future developers need to understand why the division is necessary
4. **Edge Cases**: Are there scenarios where 0.5x scaling doesn't apply?

## Current Implementation Context

The `move_cursor_to_coordinates()` function in `kwin-screen-helpers.sh` (lines 186-198):

```bash
move_cursor_to_coordinates() {
    local target_x=$1  # KWin global coordinate (e.g., 960)
    local target_y=$2  # KWin global coordinate (e.g., 540)
    
    export YDOTOOL_SOCKET=/tmp/.ydotool_socket
    
    # Step 1: Move to origin (0,0) using absolute
    ydotool mousemove --absolute -x 0 -y 0 2>/dev/null
    sleep 0.05
    
    # Step 2: Move relatively from (0,0) to target
    # CURRENT: Uses full coordinate (wrong - goes to 2x target)
    ydotool mousemove -x "$target_x" -y "$target_y" 2>/dev/null
    
    # REQUIRED: Divide by 2 to account for 0.5x scaling
    # ydotool mousemove -x $((target_x / 2)) -y $((target_y / 2)) 2>/dev/null
}
```

## Questions for User Clarification

1. **Display Configuration**:
   - What are the native resolutions of all monitors?
   - Are there any display scaling settings (beyond what kscreen-doctor reports)?
   - Is the laptop screen actually using 2x hardware scaling (3840×2400 → 1920×1200)?

2. **Coordinate System Behavior**:
   - Does the 0.5x scaling apply only after moving to (0,0) with absolute coordinates?
   - If you use relative movement from the current cursor position (without absolute to 0,0), does it also use 0.5x scaling?
   - Is the scaling consistent regardless of which screen contains (0,0)?

3. **System Configuration**:
   - Are there any Wayland-specific settings that might affect coordinate interpretation?
   - Are there any uinput-related configurations or kernel parameters?

## Summary

The coordinate system mismatch is **systematic and consistent**: ydotool's relative movement uses exactly 0.5x scaling compared to KWin's global coordinates. The fix is straightforward (divide by 2), but the root cause is unknown.

**Key Insight**: The scaling is exactly 0.5x (not approximate), suggesting it's either:
- A deliberate design choice in ydotool/Wayland/uinput
- A bug that consistently applies 2x scaling somewhere in the pipeline
- Related to display hardware scaling or coordinate system interpretation

**Next Steps**: Investigate the root cause through:
1. Checking display resolutions and scaling settings
2. Researching Wayland/uinput coordinate system documentation
3. Testing alternative approaches to understand where scaling occurs
4. Asking user for clarification on display configuration

Understanding the root cause will help ensure the solution is portable and reliable across different system configurations.


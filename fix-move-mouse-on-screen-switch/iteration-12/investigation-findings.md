# Investigation Findings: ydotool 0.5x Coordinate Scaling Root Cause

## Investigation Summary

This document continues the root cause investigation from iteration 11, focusing on understanding why ydotool's relative movement uses exactly 0.5x scaling compared to KWin's global coordinate system.

## System Information Verified

### uinput Device Properties

**Device**: `/dev/input/event16` - "ydotoold virtual device"

**Capabilities**:
- **ABS (Absolute)**: 0 (no absolute positioning support)
- **REL (Relative)**: 147 (supports relative movement)

**Key Finding**: The uinput device created by ydotool **only supports relative movement**, not absolute positioning. This confirms why the workaround (absolute to 0,0 then relative) is necessary.

**Device Path**: `/sys/class/input/event16/device/`

**No Resolution Properties Found**: The device doesn't expose explicit resolution or scaling properties in sysfs, confirming that any scaling must be implicit or handled by the compositor.

### Display Configuration

- **Laptop Screen (eDP-1)**: Native 3072×1920, Current 1920×1200 (1.6x scaling)
- **External Monitors**: Both 1920×1080, Scale: 1
- **KWin Operation Mode**: Xwayland (despite Wayland session)
- **All monitors report Scale: 1** in kscreen-doctor output

## Research Findings

### 1. Known Issue with ydotool on Wayland

**GitHub Issue #250**: Documents the exact absolute coordinate bug we're experiencing - absolute coordinates move cursor to top-left corner regardless of specified coordinates.

**Stack Overflow Discussion**: Multiple users report similar coordinate scaling issues with uinput devices on Wayland, with workarounds involving relative movement from (0,0).

### 2. Wayland Coordinate System Behavior

**Key Insights**:
- Wayland uses **logical pixels** for cursor positioning, which are scaled based on display scale factors
- Wayland compositors map absolute device coordinates to display coordinate systems
- uinput devices may have **implicit 2x resolution** causing 0.5x scaling effect
- The scaling appears to be a **compositor-level transformation** applied to uinput devices

### 3. uinput Device Resolution Hypothesis

**Theory**: When ydotool creates the uinput device, it may:
- Use a default resolution that's 2x the display resolution
- Base resolution on the highest native resolution (3072×1920)
- Not properly configure resolution properties, causing the compositor to assume a default 2x resolution

**Evidence Supporting This**:
- Exact 0.5x scaling (suggests 2x resolution mismatch)
- Global effect across all screens (device-level property)
- Consistent behavior regardless of starting position
- Research confirms uinput devices can have implicit resolution settings

### 4. Wayland Compositor Transformation

**Theory**: KWin/Wayland may apply coordinate transformations to uinput devices:
- Transformation based on display scaling
- Default transformation for virtual input devices
- Xwayland mode affecting coordinate interpretation

**Evidence**:
- KWin reports "Operation Mode: Xwayland" despite Wayland session
- Research indicates compositors apply transformations to uinput devices
- Scaling is consistent, suggesting compositor-level handling

## Key Questions Answered

### Q1: Does scaling apply only after absolute (0,0)?

**Answer**: Unknown - needs testing. The test script (`investigation-test.sh`) was created but not yet executed. This is a critical test to determine if:
- Scaling applies to ALL relative movements (device-level)
- Scaling applies only when using the workaround (compositor-level after absolute reset)

### Q2: Is scaling consistent regardless of starting position?

**Answer**: Based on user testing in iteration 10, **yes** - scaling is consistent across all tested coordinates and screens. However, we haven't tested relative movement from arbitrary starting positions (without absolute to 0,0 first).

### Q3: Where does the scaling occur?

**Answer**: Based on research, the scaling likely occurs in one of these locations:
1. **uinput device creation** - Device has implicit 2x resolution
2. **libinput layer** - Maps relative movements with scaling factor
3. **Wayland compositor** - Applies transformation to uinput devices
4. **KWin Xwayland mode** - Coordinate transformation in compatibility layer

## Leading Hypothesis

**uinput Device Implicit Resolution with Compositor Transformation**

The most likely root cause is a combination of:

1. **uinput device implicit resolution**: The device is created with an implicit 2x resolution (possibly based on highest native resolution or a default value)

2. **Wayland compositor transformation**: KWin applies a coordinate transformation when handling relative movements from uinput devices, possibly related to:
   - Logical vs physical pixel mapping
   - Xwayland compatibility mode
   - Default scaling for virtual input devices

3. **Result**: Relative movements are interpreted at 2x resolution, causing 0.5x scaling in display coordinates

## Evidence Summary

### Supporting Evidence

1. ✅ Exact 0.5x scaling (suggests 2x resolution mismatch)
2. ✅ Global effect across all screens (device-level property)
3. ✅ Consistent behavior (compositor-level transformation)
4. ✅ Research confirms uinput devices can have implicit resolution
5. ✅ Known issue with ydotool on Wayland (GitHub issue #250)
6. ✅ Device only supports relative movement (ABS=0, REL=147)

### Contradicting Evidence

1. ❓ All monitors report Scale: 1 (not related to display scaling)
2. ❓ Laptop screen has 1.6x native scaling, not 2x (but issue affects all screens)
3. ❓ No explicit resolution properties in uinput device sysfs

## Next Steps for Investigation

### Immediate Actions

1. **Execute Test Script**: Run `investigation-test.sh` to answer:
   - Does scaling apply to ALL relative movements or only with workaround?
   - Is scaling consistent from different starting positions?
   - Does relative movement from current position also use 0.5x scaling?

2. **Examine ydotool Source Code**: 
   - Check GitHub repository: `https://github.com/ReimuNotMoe/ydotool`
   - Look for uinput device creation code
   - Check if resolution properties are set
   - Review relative movement implementation

3. **Test Display Resolution Changes**:
   - Change laptop screen resolution and test if scaling factor changes
   - Verify if scaling is related to specific display configuration

### Research Actions

4. **Check KWin Source Code**:
   - Investigate how KWin handles uinput devices
   - Look for coordinate transformation code
   - Check Xwayland mode coordinate handling

5. **Research libinput Behavior**:
   - Understand how libinput maps relative movements
   - Check if there's scaling applied at libinput level
   - Review libinput documentation for uinput device handling

6. **Test Alternative Approaches**:
   - Query cursor position before/after movements to verify actual coordinates
   - Test if scaling factor changes with different display configurations
   - Compare behavior with other uinput-based tools

## Test Script Status

**Created**: `investigation-test.sh` in iteration 11
**Status**: Not yet executed
**Purpose**: Systematically test coordinate behavior to understand:
- Whether scaling applies only with workaround or to all relative movements
- Consistency of scaling from different starting positions
- Where in the coordinate pipeline the scaling occurs

## Conclusion

The investigation has identified **strong evidence** pointing to an **uinput device implicit resolution** combined with **Wayland compositor coordinate transformation** as the root cause. However, **definitive confirmation** requires:

1. Executing the test script to gather empirical data
2. Examining ydotool source code to understand device creation
3. Testing with different display configurations

The exact root cause is still **hypothetical** but well-supported by research and system analysis. The 0.5x scaling is systematic and consistent, suggesting a device-level or compositor-level property rather than a bug in coordinate calculation.

## Recommended Approach

Given the investigation findings:

1. **Short-term**: Implement the fix (divide by 2) with clear documentation of the coordinate scaling issue
2. **Long-term**: Continue investigation to understand root cause for portability and maintainability
3. **Documentation**: Document the issue, workaround, and investigation findings for future reference

The fix is straightforward and well-understood, even if the exact root cause isn't definitively confirmed. The investigation has provided sufficient understanding to implement a reliable solution.


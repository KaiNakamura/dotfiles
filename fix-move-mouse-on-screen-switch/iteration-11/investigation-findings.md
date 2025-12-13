# Investigation Findings: ydotool 0.5x Coordinate Scaling

## System Information Gathered

### Display Configuration

**Laptop Screen (eDP-1)**:
- Native resolution: **3072×1920** (highest available mode)
- Current resolution: **1920×1200** (mode 6, marked with *)
- Scaling factor: 3072/1920 = **1.6x** (not 2x as previously thought)
- Geometry: 975,1080 1920×1200
- Scale: 1 (KDE display scaling)

**External Monitors**:
- **DP-5** (left): 1920×1080, Geometry: 0,0 1920×1080, Scale: 1
- **HDMI-A-1** (right): 1920×1080, Geometry: 1920,0 1920×1080, Scale: 1

**Key Finding**: The laptop screen has a native resolution of 3072×1920, not 3840×2400 as mentioned in previous notes. However, the 0.5x scaling issue affects ALL screens uniformly, not just the laptop screen.

### uinput Device Information

**ydotoold Virtual Device**:
- Device name: "ydotoold virtual device"
- Event device: `/dev/input/event16`
- Sysfs path: `/sys/class/input/event16/device`
- Device type: Supports relative movement (REL=147)
- No explicit resolution properties found in sysfs

**Key Finding**: The uinput device doesn't expose resolution or scaling properties that we can query directly.

### ydotool Daemon Status

- **Running**: Yes (PID 26148)
- **Socket**: `/tmp/.ydotool_socket`
- **Socket permissions**: 0666 (configured)
- **Command**: `/usr/local/bin/ydotoold --socket-path=/tmp/.ydotool_socket --socket-perm=0666`

### Session Information

- **XDG_SESSION_TYPE**: wayland (confirmed Wayland session)
- **WAYLAND_DISPLAY**: wayland-0
- **DISPLAY**: :1 (Xwayland compatibility)
- **KWin Operation Mode**: Xwayland (KWin reports "Operation Mode: Xwayland" in supportInformation)
- **KWin Version**: 5.27.11

**Key Finding**: Despite being a Wayland session, KWin reports "Operation Mode: Xwayland", which suggests it may be running in Xwayland compatibility mode. This could potentially affect coordinate system interpretation.

## Coordinate System Observations

### Known Behavior

1. **Absolute coordinates**: Don't work correctly (moves to top-left corner)
2. **Workaround**: Absolute to (0,0) then relative movement works, but uses 0.5x scaling
3. **Scaling factor**: Exactly 0.5x (half scale) - consistent across all screens and coordinates
4. **Test results** (from iteration 10):
   - Left monitor center: (960, 540) → requires (480, 270) ✓
   - Right monitor center: (2880, 540) → requires (1440, 270) ✓
   - Top edge: (1920, 0) → requires (960, 0) ✓
   - Bottom monitor center: ~(1851, 1680) → requires (960, 810) ✓

### Unanswered Questions

1. **Does scaling apply only after absolute (0,0)?**
   - Need to test: Relative movement from current position (without absolute to 0,0)
   - Hypothesis: Scaling might only apply when using the workaround

2. **Is scaling consistent regardless of starting position?**
   - Need to test: Relative movement from different starting positions
   - Hypothesis: Scaling might be consistent, but needs verification

3. **Where does the scaling occur?**
   - In ydotool's relative movement calculation?
   - In the uinput device configuration?
   - In Wayland's handling of uinput input?
   - In KWin's transformation of uinput events?

## Hypotheses Status

### Hypothesis 1: Wayland Logical vs Physical Pixels
**Status**: Unlikely - All monitors show Scale: 1, and scaling is exactly 0.5x consistently
**Evidence**: KWin coordinates are likely physical pixels, and the scaling is too consistent to be a logical/physical mismatch

### Hypothesis 2: Display Scaling at Hardware Level
**Status**: Partially investigated - Laptop screen has 1.6x native resolution scaling, but issue affects all screens
**Evidence**: The 0.5x scaling is global, not screen-specific, so hardware scaling on one screen is unlikely the cause
**Next**: Need to verify if changing laptop screen resolution affects scaling

### Hypothesis 3: uinput Device Configuration
**Status**: Investigated - No resolution properties found
**Evidence**: uinput device doesn't expose resolution/scaling properties
**Next**: May need to check uinput kernel module or Wayland compositor handling

### Hypothesis 4: Wayland Compositor Input Transformation
**Status**: Needs investigation
**Evidence**: Wayland compositors may apply transformations to uinput devices
**Next**: Research Wayland protocol documentation and KWin source code

### Hypothesis 5: ydotool Internal Behavior
**Status**: Needs investigation
**Evidence**: Could be in ydotool's coordinate handling
**Next**: Check ydotool source code or GitHub issues

## Next Steps

1. **Run coordinate behavior tests** (investigation-test.sh):
   - Test relative movement without absolute (0,0)
   - Test relative movement from different starting positions
   - Verify if scaling is consistent

2. **Research Wayland/uinput coordinate handling**:
   - Check Wayland protocol documentation
   - Investigate KWin's handling of uinput devices
   - Look for known issues or documentation

3. **Check ydotool source code**:
   - Review how ydotool handles relative movement
   - Check if there's coordinate transformation logic
   - Look for GitHub issues related to coordinate scaling

4. **Test display resolution changes**:
   - Change laptop screen resolution and test if scaling factor changes
   - Verify if scaling is related to display configuration

## Test Script Created

Created `investigation-test.sh` to systematically test coordinate behavior:
- Direct relative movement (without absolute to 0,0)
- Workaround behavior (absolute to 0,0 then relative)
- Known working coordinates
- Relative movement from different starting positions

This will help determine:
- Whether scaling applies only with the workaround
- Whether scaling is consistent across different scenarios
- Where in the coordinate transformation pipeline the scaling occurs

## Research Findings

### Key Insights from Research

1. **libinput Coordinate Mapping**: According to Wayland/libinput documentation, devices with absolute axes send positioning data within a device-specific coordinate range, and libinput maps these coordinates to the display's logical resolution. This mapping could potentially affect relative movements as well.

2. **Xwayland Coordinate Scaling**: Research found that `xwayland_scale()` function converts Wayland logical coordinates to X11 physical coordinates by multiplying by the scale factor. Since KWin reports "Operation Mode: Xwayland", this could be relevant.

3. **Fractional Scaling and Pointer Acceleration**: A KDE bug report (bug #483067) mentions that fractional scaling can cause unwanted mouse acceleration, and there's code to ensure non-accelerated pointer values are not scaled. This suggests that scaling transformations are applied to input events.

### Leading Hypothesis

**uinput Device Resolution Mismatch**: The uinput device created by ydotool may have an implicit resolution that's 2x the display resolution, causing relative movements to appear 0.5x scaled. This could be:
- A default resolution set when the device is created
- A resolution based on the highest native resolution (3072×1920)
- A resolution that doesn't match the logical display resolution

See `investigation-hypothesis.md` for detailed hypothesis analysis.

### Next Investigation Steps

1. **Examine ydotool source code**: Check how ydotool creates the uinput device and if it sets resolution properties
2. **Test with resolution changes**: Change display resolution and verify if scaling factor changes
3. **Research uinput API**: Understand how uinput device resolution works and if it can be configured
4. **Check KWin source code**: Investigate how KWin handles uinput devices and coordinate transformations


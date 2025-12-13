# Investigation Summary: ydotool 0.5x Coordinate Scaling

## Investigation Status

**Current Phase**: Root cause hypothesis development and testing

## Key Findings

### System Configuration
- **Native Resolution**: 3072×1920 (laptop screen)
- **Current Resolution**: 1920×1200 (laptop screen)
- **Scaling Factor**: 1.6x (native to current)
- **Session**: Wayland (KWin reports Xwayland operation mode)
- **ydotool Version**: v1.0.4

### Coordinate Behavior
- **Scaling Factor**: Exactly 0.5x (half scale)
- **Consistency**: Uniform across all screens and coordinates
- **Workaround**: Absolute to (0,0) then relative movement works but uses 0.5x scaling

### uinput Device
- **Device Name**: "ydotoold virtual device"
- **Event Device**: `/dev/input/event16`
- **Capabilities**: EV=7, REL=147 (supports relative movement)
- **Resolution Properties**: None found in sysfs

## Leading Hypothesis

**uinput Device Resolution Mismatch**: The uinput device created by ydotool may have an implicit resolution that's 2x the display resolution, causing relative movements to appear 0.5x scaled.

### Why This Makes Sense

1. **Exact 0.5x scaling**: Suggests a 2x resolution mismatch
2. **Global effect**: Affects all screens uniformly, indicating device-level property
3. **No explicit resolution**: uinput devices don't expose resolution in sysfs
4. **Native resolution clue**: Laptop has high native resolution (3072×1920)

### Alternative Hypotheses

1. **Wayland Compositor Transformation**: KWin might apply coordinate transformations to uinput devices
2. **libinput Coordinate Mapping**: libinput may map relative movements differently than expected
3. **Xwayland Mode Impact**: KWin's Xwayland operation mode might affect coordinate interpretation

## Investigation Artifacts Created

1. **investigation-findings.md**: System information and observations
2. **investigation-hypothesis.md**: Detailed hypothesis analysis
3. **investigation-test.sh**: Test script for coordinate behavior
4. **investigation-summary.md**: This summary document

## Next Steps

### Immediate Actions
1. **Run test script**: Execute `investigation-test.sh` to gather empirical data
2. **Examine ydotool source**: Check GitHub repository for uinput device creation code
3. **Test resolution changes**: Change display resolution and verify if scaling changes

### Research Needed
1. **uinput API documentation**: Understand device resolution handling
2. **KWin source code**: Investigate uinput device coordinate handling
3. **Wayland protocol**: Research coordinate system specifications

### Testing Needed
1. **Coordinate behavior tests**: Verify scaling consistency across scenarios
2. **Resolution change tests**: Test if scaling factor changes with display resolution
3. **Alternative tool comparison**: Compare with other uinput-based tools

## Questions to Answer

1. Does the scaling apply only after absolute (0,0), or to all relative movements?
2. Is the scaling consistent regardless of starting position?
3. Where exactly does the scaling occur in the coordinate transformation pipeline?
4. Can the uinput device resolution be configured or queried?
5. Does changing display resolution affect the scaling factor?

## Current Understanding

The 0.5x scaling is **systematic and consistent**, suggesting it's either:
- A device-level property (uinput device resolution)
- A compositor-level transformation (KWin/Wayland coordinate handling)
- A combination of both

The fact that it's exactly 0.5x (not approximate) strongly suggests a **2x resolution mismatch** somewhere in the pipeline between:
- ydotool → uinput device → libinput → Wayland compositor → KWin

## Progress

- ✅ System information gathered
- ✅ uinput device investigated
- ✅ Research on Wayland/uinput coordinate systems
- ✅ Hypothesis developed
- ⏳ Testing coordinate behavior (test script created, needs execution)
- ⏳ Examining ydotool source code
- ⏳ Testing resolution changes


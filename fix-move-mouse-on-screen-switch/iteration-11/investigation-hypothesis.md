# Investigation Hypothesis: uinput Device Resolution and Coordinate System

## Key Insight

After investigating the system, I've discovered a potential root cause for the 0.5x coordinate scaling:

### uinput Device Behavior

**uinput devices don't have explicit resolution properties** - they only send relative movement events. The compositor (KWin/Wayland) interprets these relative movements and applies them to the cursor position.

### Hypothesis: Default uinput Device Resolution

**Theory**: When a uinput device is created, it may have a default or implicit resolution that differs from the actual display resolution. If the uinput device is created with a resolution that's 2x the actual display resolution, then relative movements would appear to be 0.5x scaled.

**Example**:
- Display resolution: 1920×1080 (for one monitor)
- uinput device implicit resolution: 3840×2160 (2x)
- Relative movement of 100 pixels in uinput space = 50 pixels in display space (0.5x scaling)

### Why This Could Happen

1. **uinput device creation**: When ydotool creates the uinput device, it might not specify a resolution, causing the kernel/compositor to use a default value
2. **High-DPI handling**: The system might be creating the uinput device with a resolution matching the highest native resolution (3072×1920) or a scaled version
3. **Wayland compositor interpretation**: KWin might be interpreting uinput relative movements based on a different coordinate system than the display's logical coordinates

### Evidence Supporting This Hypothesis

1. **Consistent 0.5x scaling**: The scaling is exactly 0.5x (half), suggesting a 2x resolution mismatch
2. **Global effect**: Affects all screens uniformly, suggesting it's a device-level property, not per-screen
3. **Native resolution clue**: The laptop screen has a native resolution of 3072×1920, which is 1.6x the current resolution (1920×1200)
4. **uinput device has no explicit resolution**: We couldn't find resolution properties in sysfs

### Testing This Hypothesis

To verify this hypothesis, we could:

1. **Check uinput device creation**: Look at ydotool source code to see how it creates the uinput device
2. **Test with different display resolutions**: Change the laptop screen resolution and see if the scaling factor changes
3. **Check if uinput device resolution can be configured**: Research if there's a way to set uinput device resolution explicitly
4. **Compare with other uinput tools**: See if other tools that use uinput have similar issues

### Alternative Hypothesis: Wayland Coordinate Transformation

**Theory**: Wayland/KWin might be applying a coordinate transformation to uinput devices. This could be:
- A transformation based on display scaling
- A transformation based on the highest resolution display
- A default transformation for virtual input devices

### Next Steps

1. **Examine ydotool source code**: Check how ydotool creates the uinput device and if it sets any resolution properties
2. **Test resolution changes**: Change display resolution and test if scaling factor changes
3. **Research uinput API**: Look into Linux uinput API documentation to understand how device resolution works
4. **Check KWin source code**: Investigate how KWin handles uinput devices and applies coordinate transformations

## Current Understanding

The 0.5x scaling is systematic and consistent, suggesting it's either:
- A device-level property (uinput device resolution)
- A compositor-level transformation (KWin/Wayland coordinate handling)
- A combination of both

The fact that it's exactly 0.5x (not approximate) strongly suggests a 2x resolution mismatch somewhere in the pipeline.


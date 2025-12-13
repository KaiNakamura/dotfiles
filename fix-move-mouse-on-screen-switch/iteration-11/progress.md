# Progress: Iteration 11

## Problem Context

KDE scripts for mouse cursor movement (used with keybinds like Meta+HJKL and Meta+Shift+HJKL) no longer work after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

**Current Implementation**: Screen switching scripts (`kwin-move-screen-*.sh`) have been updated to use ydotool workaround, but there's a coordinate system mismatch where ydotool's relative movement uses exactly 0.5x scaling compared to KWin's global coordinates.

## Previous Iteration Summary

**Iterations 01-09**: Set up ydotool infrastructure, discovered absolute coordinate bug, found relative movement workaround, implemented shared library pattern for screen switching scripts.

**Iteration 10**: Discovered that ydotool's relative movement coordinate system uses exactly 0.5x scaling compared to KWin's global coordinates. User testing confirmed:
- Left monitor center: (960, 540) requires (480, 270) → 0.5x
- Right monitor center: (2880, 540) requires (1440, 270) → 0.5x
- Top edge between monitors: (1920, 0) requires (960, 0) → 0.5x
- Bottom monitor center: ~(1851, 1680) requires (960, 810) → ~0.5x

While a simple fix (divide by 2) would work, the root cause is unknown and needs investigation for portability across different computer configurations.

## Current Status

**Problem**: ydotool's relative movement coordinate system uses exactly 0.5x scaling, but we don't understand WHY this happens.

**Potential Clue**: User's laptop screen (eDP-1) has native resolution of 3840×2400 but is set to 1920×1200 (2x scaling). This could be related to the coordinate system issue, but it's unclear if this is the root cause or just a coincidence.

**Screen Configuration**:
- **DP-5** (left): Geometry: 0,0 1920×1080, Scale: 1
- **HDMI-A-1** (right): Geometry: 1920,0 1920×1080, Scale: 1
- **eDP-1** (bottom): Geometry: 975,1080 1920×1200, Scale: 1 (but native: 3840×2400)

All monitors show `Scale: 1` in kscreen-doctor output, so KDE display scaling is not the issue.

## Current Iteration Goals

1. **Investigate Root Cause**: Understand WHY ydotool uses half-scale coordinates
   - Is it related to the laptop screen's 2x native resolution scaling?
   - Is it a Wayland coordinate system issue (logical vs physical pixels)?
   - Is it related to uinput device configuration?
   - Is it a ydotool-specific behavior or limitation?

2. **Test Hypotheses**:
   - Test if changing laptop screen resolution affects the scaling factor
   - Investigate Wayland's coordinate system and how it relates to ydotool
   - Research uinput device coordinate system behavior
   - Check if other systems exhibit the same scaling issue

3. **Find Robust Solution**: Develop a solution that:
   - Works across different computer configurations
   - Doesn't rely on hardcoded scaling factors
   - Understands the underlying coordinate system transformation
   - Can adapt to different display configurations

## Key Questions to Investigate

1. **Is the scaling related to the laptop screen's 2x native resolution?**
   - What happens if we change the laptop screen resolution?
   - Does the scaling factor change?
   - Is there a relationship between native resolution and coordinate system?

2. **How does Wayland handle coordinate systems?**
   - Are there logical vs physical pixel differences?
   - How does Wayland compositor (KWin) report coordinates?
   - How does uinput interpret coordinates?

3. **Is this a ydotool-specific issue?**
   - Does ydotool have configuration options for coordinate system?
   - Is this documented behavior or a bug?
   - Are there other tools that work correctly?

4. **Can we query the actual coordinate system?**
   - Is there a way to detect the scaling factor dynamically?
   - Can we query ydotool's coordinate system?
   - Can we query Wayland's coordinate system?

## Next Steps

- Research Wayland coordinate system and logical vs physical pixels
- Investigate uinput device coordinate system behavior
- Test if changing laptop screen resolution affects scaling
- Research ydotool source code or documentation for coordinate system details
- Explore ways to dynamically detect or calculate the scaling factor
- Test on different hardware configurations if possible


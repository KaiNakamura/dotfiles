# Understanding: Deep Dive into ydotool Coordinate Bug and Potential Solutions

## Problem Context

**Branch**: `fix-move-mouse-on-screen-switch`  
**Current Iteration**: `iteration-08`

### Core Problem

The `kwin-center-cursor.sh` script (and 8 related KDE window switching/moving scripts) stopped working after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and incompatible with Wayland.

**Target Script**: `kde/scripts/kwin-center-cursor.sh`
- Gets active window ID using `xdotool getactivewindow`
- Gets window geometry (X, Y, WIDTH, HEIGHT) using `xdotool getwindowgeometry`
- Calculates center coordinates: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`
- Moves cursor to center using `xdotool mousemove`

### Previous ydotool Attempts Summary

**Iterations 01-05**: Set up ydotool infrastructure:
- Created `ydotool/` package with installation script
- Configured systemd service (`ydotoold.service`)
- Set up udev rules for `/dev/uinput` permissions
- Fixed socket permissions (`/tmp/.ydotool_socket`)
- Installed both `ydotool` (CLI) and `ydotoold` (daemon) packages
- **Success**: Got basic mouse movement working
- **Critical Issue**: Absolute coordinates don't work - mouse always moves to top-left corner

**Iteration 06**: Tested various workarounds:
- Tested different coordinate values across all three monitors
- Tested moving to 0,0 first then absolute coordinates
- Tested delays between commands
- Tested different coordinate ranges
- **Result**: All approaches failed - mouse consistently moves to top-left corner
- **Finding**: GitHub issue #250 documents this exact bug

**Current Status**:
- `ydotool`: 0.1.8-3build1
- `ydotoold`: 0.1.8-3build1

## ydotool Command Syntax Analysis

### Available Commands

From `ydotool help`:
- `type` - Type text
- `recorder` - Record input
- `mousemove` - Move mouse
- `key` - Simulate key presses
- `click` - Simulate mouse clicks

### mousemove Command Syntax

From `ydotool mousemove --help`:
```
Usage: mousemove [--delay <ms>] <x> <y>
  --help                Show this help.
  --delay ms            Delay time before start moving. Default 100ms.
```

**Key Findings**:
- Only supports absolute coordinates: `ydotool mousemove <x> <y>`
- No relative movement flag (`--relative`, `-x`, `-y` flags don't exist)
- No option to query current mouse position
- `--delay` flag exists but doesn't affect coordinate behavior
- Coordinates are always treated as absolute

**Limitation**: Version 0.1.8 does not support relative movement syntax.

## The Coordinate Bug: GitHub Issue #250

### Bug Description

**Issue**: `mousemove --absolute` command moves cursor to top-left corner regardless of specified coordinates.

**Observed Behavior**:
- `ydotool mousemove 100 100` → mouse moves to top-left corner
- `ydotool mousemove 500 500` → mouse moves to top-left corner
- `ydotool mousemove 1920 1080` → mouse moves to top-left corner
- All coordinate values result in same behavior (top-left)

**Status**: Issue #250 is still open with no working solution documented.

### Root Cause Analysis

**Theoretical Causes**:

1. **uinput EV_ABS Coordinate System**:
   - uinput sends absolute coordinates via `EV_ABS` events
   - Wayland compositors may interpret these coordinates differently than X11
   - Coordinate system may not be properly initialized or scaled
   - Resolution/min/max values may not be set correctly in uinput device

2. **Wayland Compositor Interpretation**:
   - Wayland compositors handle absolute coordinates differently
   - KWin may not properly interpret absolute coordinates from uinput
   - Multi-monitor setups may complicate coordinate mapping
   - Compositor may default to top-left when coordinate interpretation fails

3. **uinput Device Configuration**:
   - Virtual device may not have proper resolution set
   - `ABS_X` and `ABS_Y` axes may not be configured with correct min/max values
   - Device may be created without proper absolute coordinate capabilities

4. **Coordinate System Mismatch**:
   - Global coordinate system vs screen-local coordinates
   - Multi-monitor coordinate mapping issues
   - Scaling/DPI issues affecting coordinate interpretation

### Why Workarounds Failed

**Tested Workarounds** (from iteration 06):
1. Moving to 0,0 first then absolute coordinates - **Failed**
2. Adding delays between commands - **Failed**
3. Different coordinate ranges - **Failed**
4. Screen-specific coordinates - **Failed**

**Why They Failed**:
- All workarounds still rely on absolute coordinate interpretation
- If the compositor doesn't interpret absolute coordinates correctly, no workaround will help
- The bug appears to be at the uinput/compositor interface level, not command-line level

## Potential Solutions and Approaches

### 1. Relative Movement Workaround

**Concept**: Calculate relative movement from current position to target position.

**Requirements**:
- Need to query current mouse position
- Calculate delta: `delta_x = target_x - current_x`, `delta_y = target_y - current_y`
- Use relative movement (if supported)

**Challenges**:
- **ydotool doesn't support relative movement** in version 0.1.8
- **ydotool doesn't provide command to query current mouse position**
- Would need alternative method to get current position

**Potential Implementation**:
- Use `xdotool getmouselocation` (works on Wayland via Xwayland) to get current position
- Calculate relative delta
- **Problem**: Still need relative movement capability in ydotool

**Status**: Not viable with current ydotool version (no relative movement support).

### 2. Query Current Position via Alternative Methods

**Discovery**: `xdotool getmouselocation` works on Wayland!

**Test Result**:
```bash
$ xdotool getmouselocation
x:1920 y:1140 screen:0 window:1289
```

**Implications**:
- Can query current mouse position even on Wayland
- Uses Xwayland compatibility layer
- Provides x, y coordinates in global coordinate system

**Potential Use**:
- Get current position before moving
- Calculate relative movement needed
- **Still blocked**: ydotool doesn't support relative movement

**Status**: Useful for position querying, but doesn't solve movement issue.

### 3. Build ydotool from Source with Patches

**Approach**: 
- Get ydotool source code from GitHub
- Investigate coordinate bug in source
- Apply patches or modifications
- Build custom version

**Considerations**:
- Requires C/C++ development skills
- Need to understand uinput API and Wayland interaction
- May require debugging compositor interaction
- Maintenance burden of custom build

**Research Needed**:
- Examine ydotool source code for coordinate handling
- Understand how uinput device is configured
- Investigate EV_ABS event generation
- Check if newer versions fix the bug

**Status**: Potentially viable but requires significant development effort.

### 4. Alternative Tools

**Research Findings**:

**kdotool**:
- Designed for KDE/KWin environments
- Uses KWin scripting API
- **Limitation**: Doesn't support cursor movement (confirmed in iteration 07)

**wtype**:
- Keyboard input simulation for Wayland
- **Limitation**: No mouse movement support

**wayland-automation**:
- Python tool for Wayland automation
- Uses virtual devices
- **Status**: Compatibility with KWin unclear, needs testing

**wcentermouse**:
- Tool mentioned in KDE forums
- Centers mouse on Wayland using uinput
- **Status**: Availability and implementation details unclear

**Status**: Alternative tools either don't support cursor movement or are untested.

### 5. uinput Device Configuration Investigation

**Hypothesis**: The uinput device may not be configured with correct resolution/range.

**What to Investigate**:
- How ydotool creates uinput device
- What resolution/min/max values are set
- Whether device capabilities include absolute coordinates
- Whether Wayland compositor recognizes device capabilities

**Potential Fix**:
- Modify ydotool to set proper device resolution
- Ensure ABS_X and ABS_Y axes have correct min/max
- Verify device reports absolute coordinate capability

**Status**: Requires source code investigation and potentially custom build.

### 6. Multi-Monitor Coordinate System

**Current Setup** (from iteration 06):
- 3 monitors with global coordinate system:
  - DP-5 at 0,0 (1920x1080)
  - HDMI-A-1 at 1920,0 (1920x1080)
  - eDP-1 at 891,1080 (1920x1080)

**Hypothesis**: 
- Bug may be related to multi-monitor coordinate handling
- uinput device may need to know about monitor layout
- Coordinate system may need to account for monitor offsets

**Investigation Needed**:
- Test on single-monitor setup to see if bug persists
- Check if uinput device needs monitor information
- Investigate how Wayland handles multi-monitor absolute coordinates

**Status**: Worth testing but may not be root cause.

### 7. Wayland Protocol Investigation

**Research Finding**: 
- Wayland's security model restricts programmatic input control
- Absolute coordinates may not be supported the same way as X11
- Compositors handle input differently

**Considerations**:
- May be fundamental limitation of Wayland
- May require compositor-specific solutions
- May need to use different approach entirely

**Status**: May explain why absolute coordinates don't work, but doesn't provide solution.

## Key Insights from Research

### What Works

1. **ydotool moves the mouse** - Basic functionality works (mouse moves)
2. **xdotool getmouselocation works on Wayland** - Can query current position via Xwayland
3. **Infrastructure is set up correctly** - Daemon, permissions, service all working

### What Doesn't Work

1. **Absolute coordinates** - Always go to top-left regardless of values
2. **Relative movement** - Not supported in version 0.1.8
3. **Position querying** - ydotool doesn't provide this capability
4. **Workarounds** - All tested approaches failed

### Promising Avenues

1. **xdotool getmouselocation** - Works on Wayland, can get current position
2. **Source code investigation** - May reveal fixable issues in coordinate handling
3. **Alternative tools** - wayland-automation, wcentermouse worth testing
4. **Custom uinput solution** - Could work around ydotool bugs

## Critical Unknowns

1. **Why does the bug occur?**
   - Is it uinput device configuration?
   - Is it Wayland compositor interpretation?
   - Is it coordinate system mismatch?
   - Is it fundamental Wayland limitation?

2. **Does relative movement exist in newer versions?**
   - What versions of ydotool exist?
   - Do newer versions fix the bug?
   - Is relative movement planned or available?

3. **Can we query mouse position via other methods?**
   - KWin D-Bus methods?
   - Other Wayland protocols?
   - Alternative tools?

4. **Is the bug compositor-specific?**
   - Does it occur on other Wayland compositors?
   - Is it KWin-specific?
   - Would it work on Sway/Hyprland?

5. **Can we fix it by modifying uinput device?**
   - What resolution should device report?
   - What min/max values are needed?
   - Can we configure device differently?

## Questions for Clarification

1. **Development Approach**:
   - Are you willing to build ydotool from source to investigate/fix?
   - Should we test alternative tools first?
   - Should we investigate source code before attempting fixes?

2. **Testing Priority**:
   - Should we test on single-monitor setup first?
   - Should we test alternative tools (wayland-automation, wcentermouse)?
   - Should we investigate ydotool source code?

3. **Solution Scope**:
   - Are you open to custom uinput-based solution if ydotool can't be fixed?
   - Should we focus on ydotool fixes only?
   - Are hybrid solutions acceptable (xdotool for position + ydotool for movement)?

4. **Version Investigation**:
   - Should we check if newer ydotool versions exist?
   - Should we check GitHub for patches or fixes?
   - Should we investigate if issue #250 has any updates?

## Next Steps

1. **Investigate ydotool Source Code**:
   - Check GitHub repository for issue #250 details
   - Examine source code for coordinate handling
   - Look for device configuration code
   - Check if newer versions exist

2. **Test Alternative Approaches**:
   - Test `xdotool getmouselocation` reliability
   - Test alternative tools (wayland-automation, wcentermouse)
   - Test on single-monitor setup

3. **Investigate uinput Device**:
   - Check how ydotool creates uinput device
   - Verify device capabilities and resolution
   - Test if device configuration can be modified

4. **Consider Custom Solution**:
   - Evaluate building custom uinput-based tool
   - Assess development effort required
   - Determine if it's worth the complexity

## Understanding Summary

**ydotool Coordinate Bug Deep Dive**:

1. **The Bug**: Absolute coordinates always move mouse to top-left corner, regardless of specified values. This is documented in GitHub issue #250 and remains unresolved.

2. **Command Limitations**: Version 0.1.8 doesn't support relative movement or position querying, limiting workaround options.

3. **Key Discovery**: `xdotool getmouselocation` works on Wayland (via Xwayland), providing a way to query current mouse position.

4. **Root Cause Unknown**: The bug could be due to:
   - uinput device configuration issues
   - Wayland compositor interpretation problems
   - Coordinate system mismatches
   - Fundamental Wayland limitations

5. **Potential Solutions**:
   - Investigate source code and potentially build custom version
   - Test alternative tools (wayland-automation, wcentermouse)
   - Use `xdotool getmouselocation` + custom relative movement solution
   - Build custom uinput-based tool

**Key Challenge**: The bug appears to be at the uinput/compositor interface level, making command-line workarounds ineffective. A solution likely requires either fixing ydotool itself, finding an alternative tool, or building a custom solution.

**Most Promising Approaches**:
- Investigate ydotool source code to understand and potentially fix the bug
- Test alternative tools that may work better with KWin
- Use `xdotool getmouselocation` + develop custom relative movement solution
- Consider building custom uinput-based tool if other approaches fail



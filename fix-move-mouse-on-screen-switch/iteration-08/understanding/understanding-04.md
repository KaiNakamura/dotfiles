# Understanding: GitHub Issue #250 - ydotool Absolute Coordinate Bug

## Problem Context

**Branch**: `fix-move-mouse-on-screen-switch`  
**Current Iteration**: `iteration-08`  
**GitHub Issue**: [ReimuNotMoe/ydotool#250](https://github.com/ReimuNotMoe/ydotool/issues/250)

### Issue Summary

GitHub issue #250 reports a critical bug in `ydotool` where the `mousemove --absolute` command fails to move the mouse cursor to the specified coordinates. Instead, regardless of the input coordinates, the cursor consistently moves to the upper-left corner of the screen (coordinate 0,0).

**Issue Details**:
- **Reporter**: JakobDev
- **Opened**: July 27, 2024
- **Status**: Open (unresolved as of research date)
- **Reactions**: 28+ users have reacted with 👍, indicating widespread impact
- **Command Affected**: `ydotool mousemove --absolute <x> <y>`

### Issue Description

The issue states:
> `ydotool mousemove --absolute` just moves the Mouse to the upper left Corner of the Screen, no matter which coordinates are entered.

**Expected Behavior**:
- `ydotool mousemove --absolute X Y` should move the mouse cursor to the exact screen coordinates (X, Y)

**Actual Behavior**:
- The mouse cursor moves to the top-left corner (0, 0) regardless of the specified coordinates
- This occurs consistently across different coordinate values
- The command executes without errors, but produces incorrect results

## Context from This Codebase

### Related Test Scripts

This codebase contains test scripts that document attempts to work around this issue:

1. **`ydotool-test.sh`**:
   - Basic test script that verifies ydotool installation and daemon status
   - Contains a warning comment: "On Wayland, ydotool may move mouse to top-left corner instead of specified coordinates (known bug)"

2. **`ydotool-coordinate-test.sh`**:
   - Comprehensive test script that attempts various coordinate approaches
   - Tests coordinates across multiple monitors (DP-5, HDMI-A-1, eDP-1)
   - Tests different coordinate ranges (small: 10,10; medium: 1920,1080; monitor-specific)
   - Tests with `--delay` flag
   - **Result**: All tests fail - mouse consistently moves to top-left corner

3. **`ydotool-relative-test.sh`**:
   - Tests workaround approaches mentioned in GitHub issue comments
   - Attempts moving to 0,0 first, then using absolute coordinates
   - Tests with different delays (0.05s, 0.1s) between commands
   - **Result**: Workarounds don't work - mouse still moves to top-left

### Previous Iteration Findings

From `iterations.md` (Iteration 06):
- **Status**: Blocked - no working workaround found
- **Approach**: Tested various coordinate approaches and investigated workarounds from GitHub issue #250
- **Blocker**: All tested approaches failed - mouse consistently moves to top-left corner regardless of:
  - Coordinate values (small, large, monitor-specific)
  - Moving to 0,0 first before target coordinates
  - Adding delays between commands
  - Different coordinate ranges
- **Key Finding**: ydotool version 0.1.8-3build1 doesn't support `-x`/`-y` flags or relative movement syntax
- **Conclusion**: GitHub issue #250 is still open with no working solution

## Technical Analysis

### ydotool Command Syntax

**Current Syntax** (from test scripts):
- Absolute movement: `ydotool mousemove <x> <y>` (no `--absolute` flag needed, coordinates are absolute by default)
- Note: The issue mentions `--absolute` flag, but actual syntax may differ by version

**Version Information**:
- Ubuntu/Debian package version tested: `0.1.8-3build1`
- This version doesn't support `-x`/`-y` flags mentioned in some documentation
- Relative movement syntax may not be available in this version

### How ydotool Works

**Architecture**:
- Uses `uinput` kernel module to emulate input devices
- Requires `ydotoold` daemon to be running
- Communicates with daemon via Unix socket (`/tmp/.ydotool_socket`)
- Requires root permissions or membership in `input` group

**Input Handling**:
- ydotool creates virtual input devices via `uinput`
- Sends input events to the kernel
- The kernel forwards events to the compositor (KWin in this case)
- The compositor processes events and updates cursor position

### Why the Bug Occurs

**Hypotheses**:

1. **Coordinate Parsing Issue**:
   - The command may not be correctly parsing the coordinate arguments
   - Arguments might be ignored or misinterpreted
   - Default behavior might be falling back to (0, 0)

2. **Coordinate Translation Problem**:
   - Coordinates might be parsed correctly but not translated properly
   - There could be an issue with coordinate system mapping
   - Multi-monitor setups might confuse the coordinate system

3. **Wayland Compositor Interaction**:
   - The bug might be specific to Wayland compositors (KWin)
   - Wayland's security model might interfere with coordinate handling
   - The compositor might be rejecting or modifying coordinates

4. **uinput Event Generation**:
   - The uinput events might be generated incorrectly
   - Absolute position events might not be formatted correctly
   - The kernel might not be receiving proper coordinate data

5. **Version-Specific Bug**:
   - The bug might be present in specific versions of ydotool
   - Different versions might have different command syntax
   - The `--absolute` flag might not be implemented correctly

### Evidence from Test Scripts

**What Works**:
- ydotool can move the mouse cursor (basic functionality works)
- The daemon communication works (commands execute without errors)
- Mouse movement occurs (cursor does move, just to wrong location)

**What Doesn't Work**:
- Absolute coordinates are ignored or misinterpreted
- All coordinate values result in movement to (0, 0)
- Workarounds (moving to 0,0 first, delays) don't help
- Different coordinate ranges don't change behavior

## Impact Assessment

### Severity

**High Impact**:
- Makes `ydotool mousemove --absolute` essentially unusable for its intended purpose
- Affects any automation or scripting that relies on absolute cursor positioning
- 28+ users have reacted to the issue, indicating widespread impact
- Issue has been open since July 2024 without resolution

### Use Case Impact

**This Codebase's Use Case**:
- The `kwin-center-cursor.sh` script needs to move cursor to calculated center coordinates
- Requires absolute positioning to specific screen coordinates
- Multi-monitor setup requires global coordinate system support
- **Current Status**: Cannot use ydotool for this purpose due to coordinate bug

**Other Affected Use Cases**:
- Window automation scripts
- Accessibility tools requiring cursor positioning
- Testing/QA automation
- Any script requiring precise cursor placement

## Related Information

### ydotool Project Context

**Repository**: [ReimuNotMoe/ydotool](https://github.com/ReimuNotMoe/ydotool)
- Command-line automation tool for simulating input events
- Designed as a Wayland-compatible alternative to `xdotool`
- Supports various commands: `click`, `mousemove`, `type`, `key`
- Uses `uinput` for device emulation

**Command Documentation**:
- `mousemove` command supports both relative and absolute movement
- Absolute movement intended to move cursor to exact screen coordinates
- Relative movement intended to move cursor by delta values

### Wayland Context

**Wayland Limitations**:
- Wayland's security model restricts direct access to input devices
- Unlike X11, Wayland doesn't natively support programmatic cursor control
- Tools like ydotool must work within Wayland's constraints
- Compositor-specific behavior may vary

**KWin-Specific Considerations**:
- KWin is the compositor used in KDE Plasma
- KWin has its own input handling mechanisms
- The coordinate bug might be specific to KWin's interaction with ydotool
- Other compositors (Sway, Hyprland) might behave differently

## Questions for Clarification

1. **Issue Scope**:
   - Does this bug affect all Wayland compositors or just KWin?
   - Are there any compositors where absolute coordinates work correctly?
   - Does the bug occur on X11 sessions as well?

2. **Version Information**:
   - What version of ydotool was JakobDev using when reporting the issue?
   - Have there been any updates or fixes attempted since July 2024?
   - Are there any pull requests addressing this issue?

3. **Workaround Details**:
   - What specific workarounds were mentioned in issue comments?
   - Were any workarounds successful for other users?
   - What was the rationale behind trying to move to 0,0 first?

4. **Root Cause Investigation**:
   - Has the ydotool codebase been examined to identify the bug?
   - Is this a known limitation or an actual bug?
   - Are there any related issues or discussions?

5. **Alternative Solutions**:
   - Are there any forks or patches that fix this issue?
   - Is there a different version or build that works correctly?
   - Are there alternative tools that work better for absolute positioning?

## Understanding Summary

GitHub issue #250 documents a critical bug in `ydotool` where the `mousemove --absolute` command fails to position the cursor correctly. Instead of moving to specified coordinates, the cursor consistently moves to the top-left corner (0, 0) regardless of input values.

**Key Facts**:
- Issue opened July 27, 2024, still open and unresolved
- Affects 28+ users (based on reactions)
- Bug prevents absolute cursor positioning from working
- **CONFIRMED**: Bug persists in v1.0.4 (latest release as of Jan 2023)
- **CONFIRMED**: Disabling mouse acceleration does not fix the issue
- **CONFIRMED**: Arguments are parsed correctly (debug output shows correct parsing)
- Bug appears to be in daemon's coordinate handling, not argument parsing

**Technical Context**:
- ydotool uses `uinput` to emulate input devices
- Requires `ydotoold` daemon running
- Basic mouse movement works, but absolute coordinates are broken
- Relative movement (`-x`, `-y` without `--absolute`) may work
- Test scripts in this codebase confirm the bug persists even with:
  - v1.0.4 (upgraded from 0.1.8)
  - Mouse acceleration disabled (set to 0)
  - Correct socket configuration
  - Proper daemon setup

**Impact on This Codebase**:
- Directly blocks the use of ydotool for `kwin-center-cursor.sh` script
- Prevents absolute cursor positioning needed for window centering
- Forces exploration of alternative solutions (KWin APIs, custom tools, etc.)

**Testing Results**:
- ✅ v1.0.4 installed and running correctly
- ✅ Socket path configured (`/tmp/.ydotool_socket`)
- ✅ Mouse acceleration disabled (`XLbInptPointerAcceleration=0`)
- ✅ Arguments parsed correctly (debug output confirms)
- ❌ Absolute coordinates still move to top-left corner (0,0)
- ❓ Relative movement needs testing as potential workaround

**Critical Unknowns**:
- Root cause of the coordinate bug in daemon
- Whether bug affects all compositors or just KWin
- If relative movement can be used as workaround
- Whether this is fixable or requires alternative solutions entirely

**Next Steps for Investigation**:
1. Test if relative movement works correctly
2. Explore workaround using relative movement from known position
3. Investigate KWin D-Bus or scripting APIs as alternatives
4. Consider custom uinput-based solution
5. Determine if bug can be fixed by examining ydotool source code



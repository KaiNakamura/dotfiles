# Understanding: Research on Mouse Movement Tools for KDE Plasma on Wayland

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

**Usage Context**:
- Called by 8 other scripts after window operations:
  - `kwin-switch-*.sh` (4 scripts: left, right, up, down) - switch windows
  - `kwin-move-screen-*.sh` (4 scripts: left, right, up, down) - move windows between screens
- All scripts use `qdbus` to invoke KWin shortcuts, then call `kwin-center-cursor.sh` to center the cursor

### Previous Attempts Summary

**Iterations 01-05**: Set up `ydotool` infrastructure and got basic mouse movement working, but discovered coordinate accuracy bug (mouse always moves to top-left corner).

**Iteration 06**: Tested various workarounds for `ydotool` coordinate bug - all failed. GitHub issue #250 documents this unresolved bug.

**Iteration 07**: Investigated KWin JavaScript scripting API:
- Successfully accessed scripting console and loaded scripts via D-Bus
- Tested `workspace.cursorPos = Qt.point(x, y)` assignment
- **Result**: Scripts execute without errors but cursor does not move
- API appears to be read-only or non-functional for cursor movement in Wayland

## Research Findings: Mouse Movement Tools on KDE Plasma/Wayland

### 1. Wayland Protocol Limitations

**Fundamental Constraint**:
- Wayland's design philosophy emphasizes security by restricting direct access to input devices
- Unlike X11, Wayland does not natively support absolute cursor positioning due to security considerations
- This architectural limitation affects all tools that attempt to programmatically control the cursor

**Impact**: Any solution must work within Wayland's security model, which inherently limits programmatic cursor control.

### 2. KWin Scripting API Limitations

**Confirmed Limitations**:
- `workspace.cursorPos` property exists and is readable
- **Assignment to `workspace.cursorPos` executes without errors but does not move the cursor**
- Property appears to be read-only or non-functional for cursor movement in Wayland sessions
- Multiple syntax variations tested (direct assignment, property modification) - none work

**Status**: KWin scripting API cannot be used for cursor movement (confirmed in iteration 07).

### 3. ydotool (Previously Attempted)

**What We Know**:
- Uses `uinput` kernel module to emulate input devices
- Requires root permissions or membership in `input` group
- Basic mouse movement works (mouse moves)
- **Critical Bug**: Absolute coordinates don't work correctly - mouse always moves to top-left corner regardless of specified coordinates
- This is documented in GitHub issue #250 and remains unresolved
- No command-line workarounds exist for the coordinate issue in version 0.1.8

**Status**: Not viable for this use case due to coordinate bug.

### 4. KWin D-Bus Interface

**Research Findings**:
- KWin exposes various functionalities through D-Bus
- Direct methods for setting cursor position are not readily available or well-documented
- D-Bus interface primarily focuses on window management, not input control
- No documented D-Bus methods for cursor movement found in research

**Status**: Unlikely to provide cursor control capabilities, but may warrant further investigation.

### 5. KWin Effects API

**Potential Approach**:
- KWin Effects API offers more extensive capabilities than the standard scripting API
- Allows creation of custom effects in C++ that can interact with window management
- Might provide methods to control cursor position that aren't available in JavaScript API
- Requires developing KWin effects in C++ and integrating them into KWin environment

**Considerations**:
- Much more complex than scripting approach (requires C++ development)
- Requires compilation and integration with KWin
- Documentation and examples for cursor control are not readily available
- May require significant development effort

**Status**: Potentially viable but requires significant research and development effort.

### 6. libei (Emulated Input Protocol)

**What It Is**:
- Library that aims to provide standardized way to emulate input devices across different compositors
- Designed to be the Wayland-native replacement for tools like `xdotool`

**Current Status**:
- Adoption and support vary among compositors
- May not yet be fully integrated into KWin
- Documentation and implementation status unclear for KDE Plasma

**Status**: Promising future solution, but current support in KWin is uncertain.

### 7. wlr-virtual-pointer-unstable-v1 Protocol

**What It Is**:
- Wayland protocol for virtual pointer control
- Used by tools like `wl-kbptr` for keyboard-controlled mouse movement

**Limitation**:
- **KWin does not currently support this protocol**
- Protocol is primarily associated with wlroots-based compositors (Sway, Hyprland, etc.)
- Not applicable to KDE Plasma/KWin environments

**Status**: Not available for KWin/KDE Plasma.

### 8. Alternative Tools Found

#### wayland-automation (Python)
- Python tool for automating mouse and keyboard actions in Wayland
- Uses virtual devices to simulate interactions
- May require specific compositor support
- Status and KWin compatibility unclear

#### wl-kbptr
- Tool for controlling mouse pointer using keyboard on Wayland
- Requires `wlr-virtual-pointer-unstable-v1` protocol (not supported by KWin)
- Not applicable to KDE Plasma

#### libwldevices-go
- Go library for Wayland device protocols
- Provides implementations for virtual pointer and keyboard control
- May require protocol support that KWin doesn't provide

#### wcentermouse
- Tool mentioned in KDE forums that centers mouse on Wayland using `uinput`
- Implementation details and availability unclear
- May be a custom solution worth investigating

### 9. Recent KDE Plasma Developments

**Accessibility Features (April 2025)**:
- KDE Plasma introduced support for using number pad buttons to move the pointer on Wayland
- This demonstrates that cursor movement is possible within KWin
- May indicate internal APIs or methods that could be leveraged

**Mouse Gestures (Plasma 6)**:
- Efforts underway to implement configurable multi-touch and stroke gestures (mouse gestures) in Plasma on Wayland
- Shows ongoing development in input handling capabilities
- May provide insights into cursor control mechanisms

**Key Insight**: The number pad pointer movement feature proves that KWin can programmatically move the cursor - there must be an internal API or method that enables this.

### 10. Custom uinput-based Solutions

**Approach**:
- Develop custom tool using `uinput` kernel module directly
- Would require handling input device events at low level
- Could potentially work around `ydotool`'s coordinate bug by implementing coordinate handling differently

**Considerations**:
- Requires root permissions or `input` group membership
- Requires significant development effort (C/C++ programming)
- Need to understand why `ydotool` has coordinate bug and implement workaround
- Security implications of low-level input device access

**Status**: Potentially viable but requires custom development.

## Key Insights from Research

### What Works
1. **ydotool moves the mouse** - basic functionality works, but coordinates are broken
2. **KWin can move cursor** - proven by number pad pointer movement feature
3. **KWin scripts execute** - scripting infrastructure works, but cursor movement API doesn't

### What Doesn't Work
1. **KWin scripting API** - `workspace.cursorPos` assignment doesn't move cursor
2. **ydotool absolute coordinates** - known bug prevents accurate positioning
3. **wlr-virtual-pointer protocol** - not supported by KWin
4. **Standard Wayland protocols** - no native support for programmatic cursor control

### Promising Avenues
1. **KWin Effects API** - C++ API might have cursor control capabilities
2. **KWin internal APIs** - number pad feature proves cursor movement is possible
3. **Custom uinput solution** - could work around `ydotool` bugs
4. **libei** - future standard, but support unclear

## Critical Unknowns

1. **How does KWin's number pad pointer movement work?**
   - What internal API or method does it use?
   - Can this be accessed via D-Bus or scripting?
   - Is there a way to leverage this functionality?

2. **KWin Effects API capabilities**:
   - Does the C++ Effects API provide cursor control methods?
   - What is the complexity of developing a custom effect?
   - Are there existing examples of cursor manipulation in effects?

3. **libei support in KWin**:
   - Is libei supported in current KWin versions?
   - What is the implementation status?
   - Can it be used for cursor movement?

4. **Custom uinput solution feasibility**:
   - Why does `ydotool` have coordinate bug?
   - Could a custom implementation avoid this bug?
   - What would be required to implement?

5. **wayland-automation and wcentermouse**:
   - Do these tools work with KWin?
   - Can they be used or adapted?
   - What are their implementation details?

## Questions for Clarification

1. **Solution Complexity Tolerance**:
   - Are you open to developing a custom C++ KWin effect if that's what's required?
   - Or should we focus on simpler solutions (scripts, existing tools)?

2. **Research Priority**:
   - Should we investigate how KWin's number pad pointer movement works (since it proves cursor movement is possible)?
   - Or explore KWin Effects API documentation?
   - Or investigate custom uinput solutions?

3. **Tool Evaluation**:
   - Should we test `wayland-automation` or `wcentermouse` if they're available?
   - Or focus on KWin-native solutions?

4. **Development Approach**:
   - Are you willing to develop custom solutions if no existing tools work?
   - Or should we document limitations and wait for future KDE/libei support?

## Next Steps

1. **Investigate KWin Number Pad Feature**:
   - Research how the number pad pointer movement feature works internally
   - Check if this functionality can be accessed via D-Bus or other APIs
   - Determine if we can leverage this for cursor centering

2. **Research KWin Effects API**:
   - Find documentation on KWin Effects API
   - Look for examples of cursor manipulation in effects
   - Assess complexity of developing custom effect

3. **Evaluate Alternative Tools**:
   - Test `wayland-automation` if available
   - Research `wcentermouse` implementation
   - Check libei support status in KWin

4. **Consider Custom Solutions**:
   - Investigate why `ydotool` has coordinate bug
   - Assess feasibility of custom uinput-based tool
   - Evaluate development effort required

## Understanding Summary

Research reveals that programmatic cursor movement on KDE Plasma/Wayland is fundamentally challenging due to Wayland's security model. However, several promising avenues exist:

1. **KWin can move cursor** - proven by number pad pointer movement feature, suggesting internal APIs exist
2. **KWin scripting API doesn't work** - `workspace.cursorPos` assignment is non-functional
3. **ydotool has coordinate bug** - not viable for this use case
4. **Standard Wayland protocols unsupported** - wlr-virtual-pointer not available in KWin

**Most Promising Approaches**:
- Investigate how KWin's number pad pointer movement works (proves cursor movement is possible)
- Explore KWin Effects API (C++ API might have cursor control)
- Consider custom uinput solution (could work around ydotool bugs)
- Evaluate alternative tools like wayland-automation or wcentermouse

**Key Challenge**: Finding a method that works within KWin's architecture and doesn't require extensive custom development, while leveraging the fact that KWin clearly has the capability to move the cursor programmatically (as demonstrated by the number pad feature).



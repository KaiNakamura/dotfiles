# Concepts: Wayland Mouse Cursor Movement Solutions

## Problem Context

KDE scripts for centering the mouse cursor after window switching/moving stopped working after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and doesn't work on Wayland.

**Current Script**: `kde/scripts/kwin-center-cursor.sh`
- Gets active window ID using `xdotool getactivewindow`
- Gets window geometry using `xdotool getwindowgeometry`
- Moves cursor to center using `xdotool mousemove`

**Current State**: Installation infrastructure for `ydotool` is complete (daemon service, user group membership), but verification is pending before script modifications.

## Solution Concepts

### Concept 1: ydotool + qdbus Approach (Current Path) ⭐ **RECOMMENDED**

**Description**: Continue with the current approach - use `qdbus` to query KWin D-Bus for window information, then use `ydotool` to move the cursor.

**Implementation**:
- Replace `xdotool getactivewindow` with `qdbus org.kde.KWin /KWin org.kde.KWin.activeWindow`
- Replace `xdotool getwindowgeometry` with KWin D-Bus methods to get window geometry
- Replace `xdotool mousemove` with `ydotool mousemove --absolute`

**Pros**:
- ✅ Installation infrastructure already complete (ydotool package, daemon service)
- ✅ ydotool is specifically designed for Wayland and is actively maintained
- ✅ qdbus is native to KDE/Plasma and already available
- ✅ Minimal dependencies (only need to verify ydotool works)
- ✅ Follows the path already started in previous iterations
- ✅ Well-documented and commonly used for Wayland automation

**Cons**:
- ⚠️ Requires daemon (`ydotoold`) to be running
- ⚠️ Requires user to be in `input` group (needs logout/login)
- ⚠️ Need to research exact KWin D-Bus methods for window geometry
- ⚠️ May need to handle coordinate system differences (screen vs window coordinates)

**Next Steps**:
1. Verify ydotool functionality (current iteration goal)
2. Research KWin D-Bus methods for window geometry
3. Modify script to use qdbus + ydotool
4. Test and debug coordinate calculations

---

### Concept 2: wlr-randr + wtype/wlrctl Approach

**Description**: Use Wayland-native tools that may be simpler or more integrated with the compositor.

**Implementation**:
- Use `wlr-randr` or similar tools to get screen/window information
- Use `wtype` or `wlrctl` for mouse movement (if supported)
- Alternative: Use `swaymsg` if running Sway, or KWin-specific D-Bus methods

**Pros**:
- ✅ May be more compositor-native
- ✅ Potentially simpler API
- ✅ No daemon required (if using direct D-Bus)

**Cons**:
- ❌ `wtype` is primarily for keyboard input, not mouse movement
- ❌ `wlrctl` may not be available on KDE/Plasma
- ❌ Less documentation for KDE-specific usage
- ❌ Would require researching different tools
- ❌ May not work well with KWin (designed for wlroots-based compositors)

**Research Needed**:
- Check if KWin exposes similar D-Bus methods
- Verify mouse movement capabilities of these tools
- Check availability in Debian/Ubuntu repositories

---

### Concept 3: Pure KWin D-Bus Approach

**Description**: Use only KWin D-Bus methods for both window information and cursor movement (if KWin supports cursor movement).

**Implementation**:
- Use `qdbus` to get window information
- Use KWin D-Bus methods to move cursor (if available)
- No external tools needed beyond qdbus

**Pros**:
- ✅ No additional dependencies
- ✅ Native KDE/Plasma integration
- ✅ No daemon required
- ✅ Most integrated solution

**Cons**:
- ❌ **Unlikely**: KWin D-Bus may not expose cursor movement methods
- ❌ Would require extensive research into KWin D-Bus API
- ❌ May not be possible (cursor movement is typically compositor-level, not window manager level)
- ❌ Less flexible if KWin doesn't support it

**Research Needed**:
- Check KWin D-Bus API documentation
- Verify if cursor movement methods exist
- Test available D-Bus methods

---

### Concept 4: Hybrid: qdbus + Different Mouse Tool

**Description**: Use `qdbus` for window information (as in Concept 1) but explore alternative mouse movement tools.

**Alternatives to ydotool**:
- `wob` (Wayland overlay bar) - not applicable
- `wshowkeys` - keyboard only
- Custom D-Bus method if available
- Direct `/dev/uinput` access (more complex)

**Pros**:
- ✅ qdbus approach is solid for window info
- ✅ May find simpler mouse tool
- ✅ Flexibility to choose best tool for each task

**Cons**:
- ❌ Limited alternatives to ydotool for Wayland mouse control
- ❌ Most alternatives are keyboard-focused
- ❌ Would need to research and test multiple tools
- ❌ ydotool is already the standard solution

**Research Needed**:
- Identify viable alternatives to ydotool
- Test each alternative's mouse movement capabilities
- Compare ease of use vs ydotool

---

### Concept 5: Script Rewrite with Error Handling & Fallbacks

**Description**: Enhance Concept 1 (ydotool + qdbus) with robust error handling, fallback mechanisms, and better coordinate handling.

**Implementation**:
- Use ydotool + qdbus as primary method
- Add comprehensive error checking
- Handle multi-monitor setups properly
- Add fallback behavior if ydotool unavailable
- Better coordinate system handling (screen vs window coordinates)

**Pros**:
- ✅ Builds on proven approach (Concept 1)
- ✅ More robust and production-ready
- ✅ Better user experience with error messages
- ✅ Handles edge cases (multi-monitor, coordinate systems)

**Cons**:
- ⚠️ More complex implementation
- ⚠️ Requires more testing
- ⚠️ May be overkill for simple use case

**Enhancements**:
- Verify ydotool availability before use
- Check daemon status
- Handle coordinate system differences
- Add logging/debugging output
- Graceful degradation if tools unavailable

---

## Recommendation Summary

**Primary Recommendation**: **Concept 1 (ydotool + qdbus)** - This is the most straightforward path forward given that:
1. Installation infrastructure is already complete
2. ydotool is the standard Wayland mouse control tool
3. qdbus is native to KDE/Plasma
4. Minimal additional research needed
5. Well-documented approach

**Secondary Consideration**: **Concept 5** - Enhance Concept 1 with better error handling and robustness, but only after Concept 1 is proven to work.

**Not Recommended**: Concepts 2, 3, and 4 - These either require extensive research into tools that may not exist/work, or explore alternatives that are less standard than ydotool.

## Decision Points for User

1. **Proceed with Concept 1?** - Continue with ydotool + qdbus approach after verification
2. **Add Concept 5 enhancements?** - Include robust error handling from the start, or add later?
3. **Explore Concept 3 first?** - Research if KWin D-Bus can move cursor before committing to ydotool?
4. **Multi-monitor handling priority?** - How important is proper multi-monitor coordinate handling?

## Next Steps (Assuming Concept 1)

1. **Complete verification** (current iteration):
   - Verify `ydotoold` daemon is running
   - Test `ydotool mousemove` commands
   - Understand coordinate system

2. **Research KWin D-Bus methods**:
   - Find method to get active window ID
   - Find method to get window geometry (X, Y, WIDTH, HEIGHT)
   - Understand output format and parsing

3. **Modify script**:
   - Replace xdotool calls with qdbus + ydotool
   - Handle coordinate calculations
   - Test with various window sizes/positions

4. **Update dependencies**:
   - Change `apply-scripts.sh` to check for `ydotool` instead of `xdotool`

## Questions for User

1. Do you want to proceed with Concept 1 (ydotool + qdbus), or explore other concepts first?
2. Should we research Concept 3 (pure KWin D-Bus) to see if cursor movement is possible without ydotool?
3. How important is multi-monitor support? (affects coordinate calculation complexity)
4. Do you want robust error handling from the start (Concept 5), or keep it simple initially?





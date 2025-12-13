# Concepts

## Problem Recap

The KDE keyboard shortcut scripts that center the mouse cursor after window switching/moving stopped working after switching to Wayland because they rely on `xdotool`, which is X11-only. The scripts use `xdotool` to:
1. Get the active window ID (`getactivewindow`)
2. Get window geometry (`getwindowgeometry`)
3. Move the mouse cursor (`mousemove`)

## Refined Solution Options

### Option 1: qdbus + ydotool Hybrid (Recommended)

**Approach:** Use `qdbus` to query KWin for window information (already used in scripts), then use `ydotool` for cursor movement.

**Implementation Details:**
- Replace `xdotool getactivewindow` → `qdbus org.kde.KWin /KWin org.kde.KWin.activeWindow` (returns window ID)
- Replace `xdotool getwindowgeometry` → Query KWin via `qdbus` for window geometry:
  - `qdbus org.kde.KWin /KWin org.kde.KWin.getWindowInfo <window_id>` or
  - Use KWin scripting API via `qdbus` to get frame geometry
- Replace `xdotool mousemove` → `ydotool mousemove <x> <y>`
- Update `apply-scripts.sh` to check for `ydotool` instead of `xdotool` and ensure `ydotoold` is running

**Pros:**
- Leverages existing `qdbus` usage pattern in the codebase
- Uses native KWin APIs for window information (more reliable than X11 tools)
- `ydotool` is actively maintained and Wayland-native
- Minimal changes to script architecture (only `kwin-center-cursor.sh` needs major changes)
- Works with any Wayland compositor for cursor movement

**Cons:**
- Requires installing `ydotool` and setting up `ydotoold` daemon (may need root/sudo)
- `qdbus` output parsing may be more complex than `xdotool`'s structured output
- Need to verify exact `qdbus` commands/methods for getting window geometry on Wayland
- Requires testing to ensure `qdbus` queries work reliably on Wayland

**Complexity:** Medium - Need to adapt window querying to `qdbus` and replace cursor movement

**Installation Impact:** Need to update `apply-scripts.sh` to check for `ydotool` and `ydotoold` instead of `xdotool`

---

### Option 2: Pure ydotool Replacement

**Approach:** Replace all `xdotool` calls with `ydotool` equivalents, using `ydotool` for both window queries and cursor movement.

**Implementation Details:**
- Replace `xdotool getactivewindow` → Not directly possible with `ydotool` alone
- Replace `xdotool getwindowgeometry` → Not possible with `ydotool` (it's input-only)
- Replace `xdotool mousemove` → `ydotool mousemove <x> <y>`
- **Problem:** `ydotool` is input-only, cannot query windows
- **Solution:** Still need `qdbus` for window information, making this essentially Option 1

**Pros:**
- `ydotool` is simpler than `xdotool` (input-only tool)
- Actively maintained for Wayland

**Cons:**
- Cannot replace all `xdotool` functionality (window queries still needed)
- Still requires `qdbus` for window information
- Less complete solution than Option 1

**Complexity:** Medium - Same as Option 1, but with acknowledgment that `ydotool` alone isn't sufficient

**Note:** This option is essentially the same as Option 1, but clarifies that `ydotool` cannot fully replace `xdotool`'s query capabilities.

---

### Option 3: KWin Scripting API (JavaScript)

**Approach:** Rewrite the functionality as a KWin script using the JavaScript API, which has native access to window information.

**Implementation Details:**
- Create a KWin script that hooks into window focus/move events
- Use KWin API to get active window and geometry directly
- Use KWin API or system calls to move cursor (may still need `ydotool` for actual movement)
- Script would be installed to `~/.local/share/kwin/scripts/` or `~/.config/kwin/scripts/`
- Need to register script in KWin settings

**Pros:**
- Native integration with KWin, no external dependencies for window queries
- Direct access to window events (can hook into focus changes automatically)
- More elegant solution - no need for separate helper script calls
- Can potentially eliminate the need for action scripts entirely (hook directly into shortcuts)
- More maintainable long-term solution

**Cons:**
- Requires rewriting in JavaScript (different language/paradigm from bash)
- KWin scripting API learning curve
- May still need `ydotool` for actual cursor movement (KWin API may not have cursor control)
- Less portable (KDE-specific solution)
- More complex to debug and maintain
- Need to research KWin scripting API capabilities for cursor movement

**Complexity:** High - Requires learning KWin scripting API and potentially hybrid approach with `ydotool`

**Research Needed:** Verify if KWin scripting API can move cursor, or if it still requires external tool

---

### Option 4: Hybrid X11/Wayland Detection

**Approach:** Detect the display server and use appropriate tools (`xdotool` for X11, `qdbus`+`ydotool` for Wayland).

**Implementation Details:**
- Check `$XDG_SESSION_TYPE` environment variable (should be "wayland" or "x11")
- Alternatively check for `$WAYLAND_DISPLAY` or `$DISPLAY` variables
- If X11: use existing `xdotool` approach
- If Wayland: use `qdbus` + `ydotool` approach (Option 1)

**Pros:**
- Maintains backward compatibility with X11
- Works in both environments seamlessly
- Can migrate gradually without breaking existing X11 setups
- Useful if you switch between X11 and Wayland sessions

**Cons:**
- More complex code with conditional logic
- Need to maintain two code paths
- Requires testing in both environments
- Still requires `ydotool` installation on Wayland systems
- `apply-scripts.sh` needs to check for both tools

**Complexity:** Medium-High - Need to implement detection and maintain dual code paths

**Best For:** Users who need to support both X11 and Wayland environments

---

### Option 5: Use wlr-randr + wtype/wlrctl (wlroots-specific)

**Approach:** Use Wayland protocol tools designed for wlroots-based compositors (though KWin is not wlroots-based).

**Implementation Details:**
- Use `wlr-randr` for display/window information (if available)
- Use `wtype` or `wlrctl` for input simulation
- **Problem:** These tools are designed for wlroots compositors (Sway, Hyprland), not KWin

**Pros:**
- Uses standard Wayland protocols
- Actively maintained tools

**Cons:**
- **Not applicable to KWin** - KWin is not wlroots-based
- These tools may not work with KDE/KWin
- Would require significant research/testing
- Likely incompatible with KWin's architecture

**Complexity:** Very High - Likely incompatible, would require extensive research

**Recommendation:** Not recommended for KWin/KDE environment

---

### Option 6: Remove Cursor Movement Feature

**Approach:** Accept that cursor movement doesn't work on Wayland and remove this functionality.

**Implementation Details:**
- Remove calls to `kwin-center-cursor.sh` from all action scripts
- Remove or deprecate `kwin-center-cursor.sh` helper script
- Keep only the window switching/moving functionality
- Update `apply-scripts.sh` to remove `xdotool` dependency check

**Pros:**
- Simplest solution - no code changes needed, just removal
- No additional dependencies
- Window switching/moving still works
- Eliminates maintenance burden

**Cons:**
- Loses desired functionality
- User experience degradation
- Doesn't solve the actual problem
- May impact workflow efficiency

**Complexity:** Low - Just remove functionality

**Recommendation:** Only if cursor movement is not important to workflow

---

### Option 7: Use KWin DBus API Directly (No External Tools)

**Approach:** Use only `qdbus`/D-Bus to interact with KWin, and see if KWin has built-in cursor movement capabilities.

**Implementation Details:**
- Query KWin via D-Bus for all window information
- Check if KWin exposes cursor movement via D-Bus API
- If yes, use KWin's native cursor movement
- If no, this option is not viable

**Pros:**
- No external dependencies
- Uses native KWin APIs
- Most integrated solution

**Cons:**
- **Likely not possible** - Wayland security model prevents compositors from moving cursor arbitrarily
- Would require extensive research into KWin D-Bus API
- May not exist as a feature

**Complexity:** Unknown - Requires research into KWin D-Bus API capabilities

**Research Needed:** Verify if KWin exposes cursor movement via D-Bus

---

## Updated Recommendations

### Primary Recommendation: **Option 1 (qdbus + ydotool)**

This is the best balance of:
- **Feasibility** - Uses proven tools (`ydotool` for Wayland, `qdbus` already in use)
- **Implementation effort** - Moderate changes to `kwin-center-cursor.sh` and `apply-scripts.sh`
- **Functionality** - Achieves desired goal of cursor centering
- **Maintainability** - Similar architecture to existing approach
- **Portability** - Works with any Wayland compositor

### Secondary Recommendation: **Option 4 (Hybrid Detection)**

If you need to support both X11 and Wayland environments, Option 4 provides the best compatibility while maintaining functionality in both.

### Alternative Consideration: **Option 3 (KWin Scripting)**

If you're open to a more significant rewrite and want a more integrated solution, Option 3 could provide a cleaner long-term architecture, but requires more research and development effort.

## Implementation Considerations

### For Option 1 (Recommended):

1. **qdbus Window Query Research Needed:**
   - Verify exact D-Bus methods to get active window ID
   - Verify exact D-Bus methods to get window geometry (X, Y, WIDTH, HEIGHT)
   - Test parsing of `qdbus` output format

2. **ydotool Setup:**
   - Installation method (package manager vs. manual build)
   - `ydotoold` daemon setup and auto-start configuration
   - Permissions/security considerations

3. **Script Updates:**
   - Modify `kwin-center-cursor.sh` to use `qdbus` + `ydotool`
   - Update `apply-scripts.sh` to check for `ydotool`/`ydotoold` instead of `xdotool`
   - Add Wayland detection if going with Option 4

4. **Testing:**
   - Test on Wayland session
   - Verify window geometry calculations are correct
   - Test with multi-monitor setups
   - Test with different window sizes/positions

## Questions for Decision

1. **Do you need to support both X11 and Wayland, or is Wayland-only acceptable?**
   - If both: Option 4 (Hybrid)
   - If Wayland only: Option 1

2. **Are you comfortable installing `ydotool` and setting up the `ydotoold` daemon?**
   - If yes: Option 1 or 4
   - If no: Consider Option 3 or 6

3. **Would you prefer maintaining the existing bash script architecture, or are you open to rewriting in JavaScript?**
   - Bash: Option 1 or 4
   - JavaScript: Option 3

4. **How important is cursor movement to your workflow?**
   - Critical: Option 1, 3, or 4
   - Nice-to-have: Could consider Option 6

5. **Are you willing to do research/testing on KWin D-Bus API methods for window geometry?**
   - Yes: Option 1 is viable
   - No: May need to explore Option 3 or accept Option 6

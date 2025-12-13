# Concepts

## Problem Recap

The KDE keyboard shortcut scripts that center the mouse cursor after window switching/moving stopped working after switching to Wayland because they rely on `xdotool`, which is X11-only.

## Solution Options

### Option 1: Replace xdotool with ydotool (Recommended)

**Approach:** Replace `xdotool` calls with `ydotool`, a Wayland-compatible input simulation tool.

**Implementation:**
- Replace `xdotool getactivewindow` → Use `qdbus` or `qdbusviewer` to query KWin for active window ID
- Replace `xdotool getwindowgeometry` → Use `qdbus` to query KWin for window geometry
- Replace `xdotool mousemove` → Use `ydotool mousemove` for cursor movement

**Pros:**
- Direct replacement approach, minimal architectural changes
- `ydotool` is actively maintained and designed for Wayland
- Similar command-line interface to `xdotool`, making migration straightforward
- Works with any Wayland compositor (not KDE-specific)

**Cons:**
- Requires installing `ydotool` (may need root/sudo for setup)
- `ydotool` requires a daemon (`ydotoold`) to be running
- Window information still needs to come from KWin via `qdbus` (not a direct replacement)
- May require additional permissions/configuration

**Complexity:** Medium - Need to adapt window querying logic while replacing cursor movement

---

### Option 2: Use KWin Scripting API (JavaScript)

**Approach:** Rewrite the functionality as a KWin script using the JavaScript API, which has native access to window information and can potentially move the cursor.

**Implementation:**
- Create a KWin script that listens for window focus changes
- Use KWin API to get active window and geometry
- Use KWin API or system calls to move cursor

**Pros:**
- Native integration with KWin, no external dependencies
- Direct access to window information without querying via `qdbus`
- Can potentially hook into window events more elegantly
- More maintainable long-term solution

**Cons:**
- Requires rewriting scripts in JavaScript (different language/paradigm)
- KWin scripting API may not have direct cursor movement capabilities
- May still need `ydotool` or similar for actual cursor movement
- Less portable (KDE-specific solution)
- Steeper learning curve

**Complexity:** High - Requires learning KWin scripting API and potentially hybrid approach

---

### Option 3: Hybrid X11/Wayland Detection

**Approach:** Detect the display server and use appropriate tools (`xdotool` for X11, `ydotool` for Wayland).

**Implementation:**
- Check `$XDG_SESSION_TYPE` or `$WAYLAND_DISPLAY` environment variable
- If X11: use existing `xdotool` approach
- If Wayland: use `ydotool` + `qdbus` approach (Option 1)

**Pros:**
- Maintains backward compatibility with X11
- Works in both environments
- Can migrate gradually

**Cons:**
- More complex code with conditional logic
- Need to maintain two code paths
- Still requires `ydotool` installation on Wayland systems

**Complexity:** Medium-High - Need to implement detection and maintain dual code paths

---

### Option 4: Use qdbus for Window Info + ydotool for Cursor

**Approach:** Query KWin via `qdbus` for window information, then use `ydotool` only for cursor movement.

**Implementation:**
- Use `qdbus org.kde.KWin /KWin org.kde.KWin.activeWindow` to get active window
- Use `qdbus` to query window geometry from KWin
- Use `ydotool mousemove` for cursor movement

**Pros:**
- Leverages existing `qdbus` calls already in the scripts
- Minimal changes to overall architecture
- Uses native KWin APIs for window info (more reliable)

**Cons:**
- Requires `ydotool` installation
- `qdbus` queries may be slower than direct API access
- Need to parse `qdbus` output (may be fragile)

**Complexity:** Medium - Similar to Option 1 but uses `qdbus` instead of direct tool

---

### Option 5: Remove Cursor Movement Feature

**Approach:** Accept that cursor movement doesn't work on Wayland and remove this functionality.

**Implementation:**
- Remove calls to `kwin-center-cursor.sh` from all scripts
- Keep only the window switching/moving functionality

**Pros:**
- Simplest solution - no code changes needed, just removal
- No additional dependencies
- Window switching/moving still works

**Cons:**
- Loses desired functionality
- User experience degradation
- Doesn't solve the actual problem

**Complexity:** Low - Just remove functionality

---

### Option 6: Use wlr-randr or wtype (wlroots-based)

**Approach:** Use Wayland protocol tools like `wtype` (for input) combined with compositor-specific APIs.

**Implementation:**
- Use KWin-specific APIs or `qdbus` for window information
- Use `wtype` or similar for cursor movement (if available)

**Pros:**
- Uses standard Wayland protocols
- Potentially more compositor-agnostic

**Cons:**
- `wtype` is primarily for keyboard input, not cursor movement
- May not be available on all systems
- Less mature tooling ecosystem
- May require additional research/testing

**Complexity:** High - Uncertain feasibility, requires investigation

---

## Recommendation

**Option 1 (ydotool replacement)** is recommended as the best balance of:
- Feasibility (proven tool, actively maintained)
- Implementation effort (moderate changes)
- Functionality (achieves desired goal)
- Maintainability (similar to existing approach)

**Option 4 (qdbus + ydotool)** is a close second, as it leverages existing `qdbus` usage in the scripts.

**Option 3 (Hybrid)** should be considered if you need to support both X11 and Wayland environments.

## Questions for Decision

1. Do you need to support both X11 and Wayland, or is Wayland-only acceptable?
2. Are you comfortable installing `ydotool` and setting up the daemon?
3. Would you prefer a KDE-specific solution (KWin scripting) or a more portable one?
4. Is maintaining the existing bash script architecture important, or are you open to rewriting in JavaScript?






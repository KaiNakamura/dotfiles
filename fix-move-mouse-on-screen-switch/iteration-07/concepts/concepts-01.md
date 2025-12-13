# Concepts: Alternatives to ydotool for Cursor Movement on Wayland

## Problem Recap

The `kwin-center-cursor.sh` script needs to:
1. Get active window geometry (position and size)
2. Calculate center coordinates: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`
3. Move cursor to those calculated coordinates

Currently uses `xdotool` which doesn't work on Wayland. `ydotool` was attempted but has a fundamental coordinate bug (always moves to top-left corner) that cannot be worked around.

## Solution Concepts (Ranked Best to Worst)

### Option 1: KWin Scripting (JavaScript API) ⭐ **RECOMMENDED**

**Approach**: Use KWin's native JavaScript scripting API to control cursor position directly within the compositor.

**How it works**:
- KWin scripts can access `workspace.cursorPos` to get current cursor position
- Scripts can potentially set cursor position using workspace methods
- Scripts run natively within KWin, avoiding Wayland security restrictions
- Can be triggered via D-Bus or integrated into window switching logic

**Implementation**:
- Create a KWin script that:
  1. Gets active window geometry (via `workspace.activeClient`)
  2. Calculates center coordinates
  3. Moves cursor using KWin's cursor control methods
- Script can be loaded automatically or invoked via D-Bus
- Could integrate cursor movement directly into window switching actions

**Pros**:
- ✅ Native Wayland/KDE integration - no security restrictions
- ✅ Runs within compositor, full access to cursor control
- ✅ No external dependencies or daemons required
- ✅ Can be bundled with window operations seamlessly
- ✅ Well-documented API for KWin scripting
- ✅ Already using qdbus in scripts, familiar pattern

**Cons**:
- ⚠️ Need to verify cursor movement methods exist in scripting API
- ⚠️ Requires learning KWin JavaScript API
- ⚠️ Scripts need to be installed and loaded by KWin
- ⚠️ May need to modify how scripts are invoked (script vs external call)

**Research Needed**:
- Verify `workspace.setCursorPos()` or equivalent method exists
- Check if cursor control is available in KWin scripting API
- Understand script installation/loading process

---

### Option 2: KWin D-Bus Interface

**Approach**: Use D-Bus to call KWin methods for cursor movement (similar to how window shortcuts are invoked).

**How it works**:
- Query KWin D-Bus interface for cursor control methods
- Use `qdbus` or `dbus-send` to invoke cursor movement
- Keep existing script structure, just replace `xdotool mousemove` with D-Bus call

**Implementation**:
- Research available D-Bus methods on `org.kde.KWin` interface
- Replace `xdotool mousemove` with D-Bus method call
- May need to query window geometry via D-Bus as well (instead of xdotool)

**Pros**:
- ✅ Already using `qdbus` in scripts - familiar tool
- ✅ No new dependencies
- ✅ Can keep existing script structure
- ✅ Native KDE integration

**Cons**:
- ⚠️ Unclear if cursor control methods exist on D-Bus interface
- ⚠️ May need to query window geometry via D-Bus (different from xdotool)
- ⚠️ D-Bus interface may be more limited than scripting API

**Research Needed**:
- List available methods on `org.kde.KWin` D-Bus interface
- Verify cursor movement methods exist
- Check if window geometry queries are available

---

### Option 3: Hybrid Approach - KWin for Geometry + Alternative for Cursor

**Approach**: Use KWin D-Bus/scripting to get window geometry, use a different method for cursor movement.

**How it works**:
- Get window geometry via KWin D-Bus or scripting
- Calculate center coordinates
- Use alternative cursor movement method (libei, custom tool, etc.)

**Implementation**:
- Replace `xdotool getwindowgeometry` with KWin D-Bus/scripting call
- Keep cursor movement separate - explore libei or other tools
- Maintains separation of concerns

**Pros**:
- ✅ Can use best tool for each task
- ✅ Window geometry via KWin is reliable
- ✅ Flexible - can swap cursor method independently

**Cons**:
- ⚠️ Still need to solve cursor movement problem
- ⚠️ More complex - two different systems
- ⚠️ May face same cursor movement limitations

**Research Needed**:
- How to get window geometry via KWin D-Bus/scripting
- Evaluate libei or other cursor movement alternatives

---

### Option 4: Libei (libinput Emulation Interface)

**Approach**: Use libei, a newer standard library for input emulation that works with Wayland's security model.

**How it works**:
- libei communicates with compositor via RemoteDesktop portal
- Uses D-Bus calls to request input emulation permissions
- Provides secure, compositor-approved input injection

**Implementation**:
- Write a small C program or use libei bindings
- Request input emulation via D-Bus portal
- Send cursor movement events through libei

**Pros**:
- ✅ Designed for Wayland - respects security model
- ✅ Standardized approach (not compositor-specific)
- ✅ Should work correctly with coordinates

**Cons**:
- ⚠️ Requires user permission/approval for input emulation
- ⚠️ May not be fully supported in KDE Plasma yet
- ⚠️ More complex - requires programming (C or bindings)
- ⚠️ Additional dependency

**Research Needed**:
- Check if libei is supported in KDE Plasma/KWin
- Understand permission/portal workflow
- Evaluate complexity vs other options

---

### Option 5: Custom KWin Effect (C++)

**Approach**: Create a custom KWin effect in C++ that handles cursor movement.

**How it works**:
- Develop a KWin effect plugin that intercepts window switching events
- Effect automatically centers cursor when windows are switched
- Built into KWin, runs natively

**Implementation**:
- Write C++ KWin effect plugin
- Hook into window focus/switch events
- Calculate and move cursor programmatically

**Pros**:
- ✅ Deep integration with KWin
- ✅ Full access to all KWin APIs
- ✅ Can handle cursor movement automatically
- ✅ No external scripts needed

**Cons**:
- ⚠️ Requires C++ development
- ⚠️ Most complex option - significant development effort
- ⚠️ Need to compile and install KWin plugin
- ⚠️ Overkill for this use case

**Research Needed**:
- KWin effect development documentation
- Example effects that manipulate cursor
- Build/installation process

---

### Option 6: Build ydotool from Latest Source

**Approach**: Check if latest ydotool source code has fixes for coordinate bug.

**How it works**:
- Build ydotool from GitHub source (latest commit)
- Test if coordinate bug is fixed in newer version
- If fixed, use updated ydotool

**Implementation**:
- Clone ydotool repository
- Build from source
- Test coordinate functionality
- If working, update installation script

**Pros**:
- ✅ Minimal changes if it works
- ✅ Already have infrastructure set up
- ✅ Could be quick if bug is fixed

**Cons**:
- ⚠️ Bug may still exist in latest source
- ⚠️ Issue #250 is still open - likely not fixed
- ⚠️ May waste time if bug persists
- ⚠️ Still relies on uinput limitations

**Research Needed**:
- Check latest ydotool commits for coordinate fixes
- Review GitHub issue #250 status
- Test latest version if available

---

## Recommendation

**Primary Recommendation**: **Option 1 (KWin Scripting)**

KWin scripting provides the most native, integrated solution that should avoid Wayland security restrictions entirely. Since scripts run within the compositor, they have direct access to cursor control without needing input emulation.

**Fallback**: **Option 2 (KWin D-Bus)** if scripting doesn't support cursor movement, or if D-Bus interface provides cursor methods.

**Avoid**: Options 3-6 are either more complex, less reliable, or unlikely to solve the fundamental problem.

## Next Steps

1. **Research KWin Scripting API**: Verify cursor movement capabilities
2. **Test D-Bus Interface**: Check if cursor methods exist
3. **Prototype**: Create a simple KWin script to test cursor movement
4. **Decide**: Choose approach based on research results

## Questions for User

1. Are you comfortable learning KWin scripting API, or would you prefer a simpler D-Bus approach?
2. Do you want to keep the existing script structure, or are you open to restructuring (e.g., integrated KWin script)?
3. Should we investigate building ydotool from source as a quick check, or skip straight to KWin solutions?



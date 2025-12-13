# Understanding: KWin D-Bus Interface Research

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
- Called by 8 other scripts after window operations
- All scripts use `qdbus` to invoke KWin shortcuts, then call `kwin-center-cursor.sh` to center the cursor
- Current D-Bus usage pattern: `qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "<Action Name>"`

## Research Objective

Investigate KWin D-Bus interface to determine if it provides methods for programmatically moving the mouse cursor, which would be a viable solution for replacing `xdotool` functionality.

## KWin D-Bus Interface Overview

### Service and Object Paths

**Primary Service**: `org.kde.KWin`

**Available Object Paths**:
- `/KWin` - Main KWin interface
- `/Scripting` - Scripting interface for loading/managing scripts
- `/KWin/Effect.WindowView1` - Window view effect interface
- `/KWin/HighlightWindow` - Window highlighting interface
- `/KWin/ScreenShot2` - Screenshot interface

### Main KWin Interface (`/KWin`)

**Available Methods** (from `qdbus org.kde.KWin /KWin`):
- `activeOutputName()` - Get active output name
- `cascadeDesktop()` - Cascade windows on desktop
- `currentDesktop()` - Get current desktop number
- `getWindowInfo(QString)` - Get window information
- `killWindow()` - Kill active window
- `nextDesktop()` - Switch to next desktop
- `previousDesktop()` - Switch to previous desktop
- `queryWindowInfo()` - Query active window information
- `reconfigure()` - Reload KWin configuration
- `replace()` - Replace window
- `setCurrentDesktop(int)` - Set current desktop
- `showDebugConsole()` - Show debug console
- `showDesktop(bool)` - Show/hide desktop
- `startActivity(QString)` - Start activity
- `stopActivity(QString)` - Stop activity
- `supportInformation()` - Get support information
- `unclutterDesktop()` - Unclutter desktop

**Properties**:
- `showingDesktop` (bool, read-only) - Whether desktop is showing

**Signals**:
- `reloadConfig()` - Configuration reloaded
- `showingDesktopChanged(bool)` - Desktop showing state changed

**Key Finding**: **No cursor movement methods found** in the main KWin interface.

### Scripting Interface (`/Scripting`)

**Available Methods** (from `qdbus org.kde.KWin /Scripting`):
- `isScriptLoaded(QString pluginName)` - Check if script is loaded
- `loadDeclarativeScript(QString filePath)` - Load declarative script
- `loadDeclarativeScript(QString filePath, QString pluginName)` - Load declarative script with name
- `loadScript(QString filePath)` - Load JavaScript script
- `loadScript(QString filePath, QString pluginName)` - Load script with custom plugin name
- `start()` - Start scripting
- `unloadScript(QString pluginName)` - Unload a script

**Key Finding**: Scripts can be loaded via D-Bus, but as confirmed in iteration 07, KWin scripts cannot move the cursor (`workspace.cursorPos` assignment doesn't work).

### Other Interfaces

**Tested Object Paths** (all returned "UnknownObject" errors):
- `/KWin/Compositor` - Does not exist
- `/KWin/Effects` - Does not exist
- `/InputDeviceManager` - Does not exist

**Available Effect Interfaces**:
- `/KWin/Effect.WindowView1` - Window view effect (specific effect, not general cursor control)
- `/KWin/HighlightWindow` - Window highlighting (not cursor control)
- `/KWin/ScreenShot2` - Screenshot functionality (not cursor control)

## Research Findings: Cursor Movement via D-Bus

### 1. Direct KWin D-Bus Methods

**Result**: ❌ **No cursor movement methods available**

- Inspected all available methods in `/KWin` interface
- No methods for setting cursor position found
- No methods for input device control found
- Interface focuses on window management, desktop switching, and configuration
- No cursor-related properties or methods discovered

**Conclusion**: KWin D-Bus interface does not provide direct cursor movement capabilities.

### 2. KWin Scripting via D-Bus

**Result**: ❌ **Not viable** (already tested in iteration 07)

- Scripts can be loaded via D-Bus: `qdbus org.kde.KWin /Scripting loadScript <path>`
- Scripts execute successfully without errors
- However, `workspace.cursorPos` assignment doesn't move the cursor
- Scripting API has same limitations as direct scripting

**Conclusion**: D-Bus script loading doesn't bypass the cursor movement limitation.

### 3. RemoteDesktop Portal

**What It Is**:
- Standardized Wayland portal for remote desktop functionality
- Provides D-Bus interface for input control
- Used by libraries like `libei` for input emulation
- Designed to work within Wayland's security model

**Service**: `org.freedesktop.portal.Desktop`

**Available Interfaces** (from inspection):
- `org.freedesktop.portal.Inhibit` - Screen inhibition
- `org.freedesktop.portal.Background` - Background apps
- `org.freedesktop.portal.Location` - Location services
- `org.freedesktop.portal.Notification` - Notifications
- `org.freedesktop.portal.Screenshot` - Screenshots
- `org.freedesktop.portal.Account` - Account information
- `org.freedesktop.portal.NetworkMonitor` - Network monitoring
- `org.freedesktop.portal.Print` - Printing
- `org.freedesktop.portal.Settings` - Settings
- `org.freedesktop.portal.GameMode` - Game mode

**RemoteDesktop Interface**:
- Attempted to access `/org/freedesktop/portal/desktop/org/freedesktop/portal/RemoteDesktop`
- **Result**: No methods returned (empty interface or requires session creation)

**Research Findings**:
- RemoteDesktop portal requires creating a session before use
- Methods like `NotifyPointerMotionAbsolute` may exist but require session setup
- Portal is designed for remote desktop applications, not general cursor control
- May require user permission/approval for input control
- Implementation complexity likely higher than direct D-Bus calls

**Status**: Potentially viable but requires significant investigation and setup.

### 4. Current D-Bus Usage in Scripts

**Existing Pattern**:
```bash
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "Switch Window Left"
```

**What This Shows**:
- Scripts already use D-Bus extensively (`qdbus`)
- Pattern is familiar and working
- D-Bus infrastructure is available and functional
- Integration with existing scripts would be straightforward if methods existed

**Key Insight**: If cursor movement methods existed, they could be easily integrated into existing script structure.

## Community Research Findings

### Forum Discussions

**KDE Forum Discussion**:
- User inquired about moving cursor via KWin scripts or D-Bus
- Response: No direct D-Bus method exists for cursor movement
- `workspace.cursorPos` is read-only in scripting API
- Confirms our findings

**KDE Discuss Thread**:
- Discussion about obtaining cursor location on Wayland
- Confirms `workspace.cursorPos` is read-only
- Mentions RemoteDesktop portal as potential alternative
- Notes that RemoteDesktop portal can move cursor but cannot read position
- Suggests `uinput`-based tools as alternative

### Documentation Findings

**Official Documentation**:
- KWin D-Bus API documentation focuses on window management
- No cursor movement methods documented
- Scripting API documentation confirms `workspace.cursorPos` is read-only
- No D-Bus methods for cursor control mentioned

**Tool Exploration**:
- `qdbusviewer` can be used to explore D-Bus interfaces interactively
- Confirms methods available match what we found via command line
- No hidden cursor movement methods discovered

## Comparison with Current Implementation

### Current Script Structure

**Window Switching Scripts** (e.g., `kwin-switch-left.sh`):
1. Execute KWin action via D-Bus: `qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "<Action>"`
2. Call helper script: `kwin-center-cursor.sh`
3. Helper script uses `xdotool` to move cursor

### If D-Bus Cursor Movement Existed

**Hypothetical Implementation**:
```bash
# Get window info via D-Bus
WINDOW_INFO=$(qdbus org.kde.KWin /KWin queryWindowInfo)
# Parse geometry from window info
# Move cursor via D-Bus
qdbus org.kde.KWin /KWin setCursorPosition $CENTER_X $CENTER_Y
```

**Advantages**:
- Native Wayland solution
- No external tools required
- Consistent with existing D-Bus usage pattern
- Would integrate seamlessly with current scripts

**Reality**: This method doesn't exist.

## Key Findings Summary

### What KWin D-Bus Provides

✅ **Window Management**:
- Window information queries (`getWindowInfo`, `queryWindowInfo`)
- Window operations (`killWindow`, `replace`)
- Desktop switching (`nextDesktop`, `previousDesktop`, `setCurrentDesktop`)
- Configuration (`reconfigure`, `showDebugConsole`)

✅ **Scripting Infrastructure**:
- Script loading/unloading (`loadScript`, `unloadScript`)
- Script status checking (`isScriptLoaded`)

✅ **Effect Interfaces**:
- Specific effect interfaces (WindowView, HighlightWindow)
- Screenshot functionality

### What KWin D-Bus Does NOT Provide

❌ **Cursor Movement**:
- No `setCursorPosition` method
- No `moveCursor` method
- No cursor-related properties (except read-only `workspace.cursorPos` in scripts)

❌ **Input Device Control**:
- No input device management interface
- No pointer control methods
- No keyboard input emulation

❌ **Direct Input Emulation**:
- No methods for simulating mouse events
- No methods for simulating keyboard events
- No low-level input control

## Alternative Approaches via D-Bus

### 1. RemoteDesktop Portal (Requires Investigation)

**Potential Approach**:
- Create RemoteDesktop portal session
- Use portal methods for cursor movement
- May require user permission/approval

**Considerations**:
- Designed for remote desktop use cases
- May require session management
- User interaction may be required for permission
- Implementation complexity unknown

**Status**: Requires significant research and testing to determine viability.

### 2. Indirect Methods (Not Viable)

**Window Geometry via D-Bus**:
- Can get window geometry via `queryWindowInfo()`
- Could calculate center coordinates
- **But**: No way to move cursor to those coordinates via D-Bus

**Conclusion**: Getting window information works, but cursor movement doesn't.

## Viability Assessment

### KWin D-Bus Interface: ❌ **Not Viable**

**Reasons**:
1. **No cursor movement methods exist** - Confirmed via inspection and documentation
2. **Scripting API limitations** - Already tested in iteration 07, doesn't work
3. **Focus on window management** - Interface designed for windows, not input control
4. **Wayland security model** - D-Bus interface respects Wayland's input restrictions

**Conclusion**: KWin D-Bus interface cannot be used for cursor movement.

### RemoteDesktop Portal: ⚠️ **Uncertain Viability**

**Reasons**:
1. **Requires session setup** - Not a simple D-Bus call
2. **Designed for remote desktop** - May not be suitable for local cursor control
3. **Permission requirements** - May require user approval
4. **Implementation complexity** - Requires significant research and development

**Conclusion**: Requires further investigation, but may be overly complex for this use case.

## Integration Considerations

### If D-Bus Solution Existed

**Integration Pattern**:
```bash
# In kwin-center-cursor.sh
WINDOW_INFO=$(qdbus org.kde.KWin /KWin queryWindowInfo)
# Parse X, Y, WIDTH, HEIGHT from window info
CENTER_X=$((X + WIDTH / 2))
CENTER_Y=$((Y + HEIGHT / 2))
qdbus org.kde.KWin /KWin setCursorPosition $CENTER_X $CENTER_Y
```

**Advantages**:
- Native Wayland solution
- Consistent with existing D-Bus usage
- No external dependencies
- Simple integration

**Reality**: This is not possible with current KWin D-Bus interface.

## Questions for Clarification

1. **RemoteDesktop Portal Investigation**:
   - Should we investigate RemoteDesktop portal session creation and cursor movement methods?
   - Or is this approach too complex for the use case?

2. **Alternative D-Bus Services**:
   - Are there other D-Bus services we should investigate?
   - Should we look at Plasma Shell D-Bus interface?

3. **Hybrid Approaches**:
   - Could we use D-Bus to get window geometry and another method to move cursor?
   - Would this be acceptable as a solution?

## Next Steps

1. **If RemoteDesktop Portal Investigation**:
   - Research RemoteDesktop portal session creation
   - Test cursor movement methods via portal
   - Evaluate complexity and user experience

2. **If Alternative Approaches**:
   - Investigate Plasma Shell D-Bus interface
   - Look for other KDE D-Bus services that might provide cursor control
   - Consider hybrid solutions (D-Bus for geometry + other method for movement)

3. **If Not Viable**:
   - Document D-Bus limitations
   - Focus on other solution approaches (KWin Effects API, custom uinput, etc.)

## Understanding Summary

**KWin D-Bus Interface Research Results**:

1. **Direct KWin D-Bus Methods**: ❌ **Not viable**
   - No cursor movement methods exist
   - Interface focuses on window management
   - No input device control capabilities

2. **KWin Scripting via D-Bus**: ❌ **Not viable**
   - Scripts can be loaded via D-Bus
   - But cursor movement doesn't work (confirmed in iteration 07)
   - Same limitations as direct scripting

3. **RemoteDesktop Portal**: ⚠️ **Uncertain**
   - May provide cursor movement capabilities
   - Requires session creation and setup
   - Designed for remote desktop use cases
   - Implementation complexity unknown

**Key Insight**: KWin D-Bus interface is designed for window management, not input control. The absence of cursor movement methods aligns with Wayland's security model, which restricts programmatic input control.

**Conclusion**: KWin D-Bus interface is **not a viable solution** for cursor movement. RemoteDesktop portal may be worth investigating, but it appears to be designed for different use cases and may be overly complex for this requirement.

**Recommendation**: Focus research efforts on other approaches (KWin Effects API, custom uinput solutions, or investigating how KWin's number pad pointer movement feature works internally).



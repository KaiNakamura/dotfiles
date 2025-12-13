# Understanding: Implementing Concept 1 - KWin Scripting for Cursor Movement

## Problem Context

**Branch**: `fix-move-mouse-on-screen-switch`  
**Current Iteration**: `iteration-07`

### Core Problem

The `kwin-center-cursor.sh` script (and related KDE window switching scripts) stopped working after switching to Wayland. The scripts currently use `xdotool`, which is X11-specific and incompatible with Wayland.

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

### Previous Attempts

**Iterations 01-06**: Attempted to use `ydotool` as a Wayland-compatible replacement for `xdotool`
- Successfully set up infrastructure (daemon, permissions, service)
- Got basic mouse movement working
- **Critical Issue**: Absolute coordinates don't work - mouse always moves to top-left corner
- This is a known bug (GitHub issue #250) that cannot be worked around
- ydotool is not viable for this use case

## Concept 1: KWin Scripting (JavaScript API)

### Proposed Approach

Use KWin's native JavaScript scripting API to control cursor position directly within the compositor, avoiding Wayland security restrictions entirely.

### How It Should Work (Concept)

1. **KWin Scripts Run Natively**: Scripts execute within KWin compositor, giving them direct access to cursor control without security restrictions
2. **Access Window Information**: Scripts can access `workspace.activeClient` to get active window geometry
3. **Cursor Control**: Scripts can potentially use `workspace.setCursorPos()` or equivalent methods to move cursor
4. **Integration Options**:
   - Script can be invoked via D-Bus (similar to current `qdbus` pattern)
   - Script can be integrated directly into window switching logic
   - Script can be loaded automatically by KWin

### Implementation Requirements

**What Needs to Be Created**:
1. A KWin JavaScript script that:
   - Gets active window geometry (via `workspace.activeClient`)
   - Calculates center coordinates: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`
   - Moves cursor to calculated coordinates using KWin API methods

2. Script installation/integration:
   - Script needs to be installed in KWin's script directory (typically `~/.local/share/kwin/scripts/`)
   - Script needs to be loaded/enabled by KWin
   - Script needs to be invokable (either via D-Bus or automatically triggered)

3. Integration with existing scripts:
   - Option A: Replace `kwin-center-cursor.sh` call with D-Bus invocation of KWin script
   - Option B: Integrate cursor movement directly into window switching actions
   - Option C: Keep script structure but call KWin script instead of shell script

### Current Implementation Details

**Existing Script Structure**:
- All `kwin-switch-*.sh` and `kwin-move-screen-*.sh` scripts follow same pattern:
  1. Execute KWin action via `qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "<Action Name>"`
  2. Call `kwin-center-cursor.sh` helper script to center cursor

**Installation Process** (`kde/apply-scripts.sh`):
- Copies all scripts to `~/.local/bin/`
- Creates desktop files for shortcuts
- Registers shortcuts in `kglobalshortcutsrc`
- Uses `kwriteconfig5` and `qdbus` for KDE integration

**D-Bus Usage**:
- Already using `qdbus` extensively for KWin integration
- Pattern: `qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "<Action>"`
- Familiar with D-Bus approach for KWin operations

## Research Needed

### Critical Unknowns

1. **Cursor Movement API**:
   - Does `workspace.setCursorPos(x, y)` or equivalent method exist?
   - What is the exact API for setting cursor position in KWin scripts?
   - Are there any limitations or restrictions?

2. **Window Geometry API**:
   - How to get active window geometry via `workspace.activeClient`?
   - What properties/methods are available on client objects?
   - How to access X, Y, WIDTH, HEIGHT values?

3. **Script Installation**:
   - Where exactly should KWin scripts be installed? (`~/.local/share/kwin/scripts/`?)
   - How are scripts loaded/enabled by KWin?
   - Do scripts need metadata files (`.desktop` or `.json`)?
   - How to reload scripts after installation?

4. **Script Invocation**:
   - Can scripts be invoked via D-Bus? What is the D-Bus interface?
   - Can scripts be triggered automatically on window focus/switch events?
   - What is the best integration pattern with existing shell scripts?

5. **KWin Scripting API Documentation**:
   - Where is the official KWin JavaScript API documentation?
   - What are the available `workspace` methods and properties?
   - Are there example scripts that manipulate cursor position?

### Known Information

- KWin supports JavaScript scripting API
- Scripts run within compositor (native Wayland integration)
- `workspace` object is available in scripts
- `workspace.activeClient` can access active window
- `workspace.cursorPos` can read cursor position (mentioned in concepts)
- Scripts can be installed and loaded by KWin
- D-Bus integration is possible (already using `qdbus`)

## Implementation Considerations

### Integration Approach Options

**Option A: Replace Shell Script with KWin Script**
- Create KWin JavaScript script that does cursor centering
- Replace `kwin-center-cursor.sh` call with D-Bus invocation of KWin script
- Keep existing script structure (8 scripts call helper)
- **Pros**: Minimal changes to existing scripts
- **Cons**: Need to verify D-Bus invocation works

**Option B: Integrate Cursor Movement into Window Actions**
- Modify KWin script to handle both window switching AND cursor centering
- Replace shell scripts entirely with KWin script actions
- **Pros**: More integrated, single script handles everything
- **Cons**: Requires restructuring all 8 scripts, more complex

**Option C: Hybrid - KWin Script Called from Shell**
- Keep shell script structure
- Replace `xdotool` calls in `kwin-center-cursor.sh` with KWin script invocation
- **Pros**: Minimal changes, keeps existing pattern
- **Cons**: Still requires shell script wrapper

### Installation Integration

**Current Installation** (`kde/apply-scripts.sh`):
- Installs shell scripts to `~/.local/bin/`
- Creates desktop files
- Registers shortcuts

**New Requirements**:
- Install KWin JavaScript script to appropriate directory
- Ensure script is loaded/enabled by KWin
- May need to update installation script to handle KWin scripts
- May need to reload KWin scripts after installation

## Questions for Clarification

1. **Script Integration Preference**:
   - Do you prefer Option A (replace shell script call with KWin script), Option B (integrate everything into KWin), or Option C (hybrid)?
   - Should we maintain the existing shell script structure, or are you open to restructuring?

2. **Script Invocation**:
   - Should the KWin script be invoked via D-Bus (similar to current `qdbus` pattern)?
   - Or should it be automatically triggered on window focus/switch events?

3. **Installation Approach**:
   - Should KWin script installation be integrated into `kde/apply-scripts.sh`?
   - Or should it be a separate installation step?

4. **Backward Compatibility**:
   - Do we need to maintain X11 compatibility (fallback to `xdotool`)?
   - Or is this Wayland-only solution acceptable?

5. **Research Priority**:
   - Should we start by researching KWin scripting API documentation and examples?
   - Or do you have access to KWin scripting resources we should check first?

## Next Steps

1. **Research KWin Scripting API**:
   - Find official KWin JavaScript API documentation
   - Verify cursor movement methods exist
   - Understand script installation/loading process
   - Find example scripts for reference

2. **Prototype**:
   - Create a simple KWin script to test cursor movement
   - Test script installation and invocation
   - Verify window geometry access

3. **Integration Planning**:
   - Decide on integration approach (A, B, or C)
   - Plan installation script modifications
   - Design script invocation method

4. **Implementation**:
   - Create KWin script for cursor centering
   - Integrate with existing scripts
   - Update installation process

## Understanding Summary

Concept 1 proposes using KWin's native JavaScript scripting API to control cursor position, which would avoid Wayland security restrictions by running within the compositor. The approach requires:

1. Creating a KWin JavaScript script that gets active window geometry and moves cursor to center
2. Installing the script in KWin's script directory and ensuring it's loaded
3. Integrating script invocation with existing shell scripts (8 scripts that currently call `kwin-center-cursor.sh`)

**Key Unknown**: Whether KWin scripting API actually supports cursor movement (`workspace.setCursorPos()` or equivalent). This needs to be verified before implementation.

**Integration Challenge**: Determining the best way to invoke the KWin script (D-Bus vs automatic trigger) and how to integrate it with the existing shell script structure.

**Research Priority**: Finding KWin JavaScript API documentation and verifying cursor control capabilities before proceeding with implementation.



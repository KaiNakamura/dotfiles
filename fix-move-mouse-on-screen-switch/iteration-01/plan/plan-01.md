# Implementation Plan: ydotool Integration

## Overview

Replace `xdotool` with `ydotool` for cursor movement on Wayland, while using `qdbus` to query KWin for window information. This implements **Option 1** from the concepts document.

## High-Level Approach

1. **Research Phase**: Identify correct `qdbus` methods to get active window ID and geometry
2. **ydotool Setup**: Install `ydotool` and configure `ydotoold` daemon
3. **Script Modification**: Update `kwin-center-cursor.sh` to use `qdbus` + `ydotool`
4. **Installation Script Update**: Update `apply-scripts.sh` to check for `ydotool` instead of `xdotool`
5. **Testing**: Verify functionality on Wayland

## Phase 1: Research & Discovery

### 1.1 Identify KWin D-Bus Methods

**Goal**: Find the correct `qdbus` commands to:
- Get the active window ID
- Get window geometry (X, Y, WIDTH, HEIGHT)

**Approach**:
- Test `qdbus org.kde.KWin /KWin org.kde.KWin.activeWindow` to get window ID
- Explore KWin D-Bus API for geometry methods:
  - Check if `getWindowInfo` exists and what it returns
  - Look for methods like `getWindowGeometry`, `getWindowFrameGeometry`, etc.
  - Test parsing of `qdbus` output format

**Deliverable**: Documented `qdbus` commands that reliably return window ID and geometry

**Questions to Answer**:
- What is the exact D-Bus method signature for getting active window?
- What method returns window geometry, and in what format?
- How do we parse `qdbus` output reliably?
- Do we need window frame geometry or client geometry?

### 1.2 Verify ydotool Capabilities

**Goal**: Confirm `ydotool` can perform absolute mouse movement

**Approach**:
- Test `ydotool mousemove --absolute -x <x> -y <y>` command
- Verify coordinate system (screen coordinates vs. window coordinates)
- Check if multi-monitor setups require special handling

**Deliverable**: Confirmed `ydotool` command syntax and coordinate system understanding

## Phase 2: ydotool Installation & Setup

### 2.1 Installation Method

**Options**:
- **A**: Package manager (if available in distribution)
- **B**: Build from source from GitHub
- **C**: Manual binary installation

**Decision Needed**: Which installation method should we use?

**Recommendation**: Check if available via package manager first, fallback to building from source

### 2.2 ydotoold Daemon Configuration

**Requirements**:
- `ydotoold` must be running as a background service
- Needs access to `/dev/uinput` (typically requires root or proper permissions)
- Should start automatically on system boot

**Implementation Options**:
- **A**: Systemd user service (`~/.config/systemd/user/ydotoold.service`)
- **B**: Manual start script with auto-start entry
- **C**: Check if running, start if not (in `apply-scripts.sh`)

**Decision Needed**: How should `ydotoold` be managed?

**Recommendation**: Systemd user service for proper lifecycle management

### 2.3 Permissions Setup

**Considerations**:
- `/dev/uinput` access may require:
  - Root permissions (not ideal)
  - udev rules to grant user access
  - Group membership (`input` group)

**Decision Needed**: How should permissions be handled?

**Recommendation**: Check if user can access `/dev/uinput`, provide instructions if not

## Phase 3: Script Implementation

### 3.1 Modify `kwin-center-cursor.sh`

**Current Implementation** (X11):
```bash
WINDOW_ID=$(xdotool getactivewindow)
eval $(xdotool getwindowgeometry --shell $WINDOW_ID)
CENTER_X=$((X + WIDTH / 2))
CENTER_Y=$((Y + HEIGHT / 2))
xdotool mousemove $CENTER_X $CENTER_Y
```

**New Implementation** (Wayland):
```bash
# Get active window ID via qdbus
WINDOW_ID=$(qdbus org.kde.KWin /KWin org.kde.KWin.activeWindow)

# Get window geometry via qdbus (method TBD in Phase 1)
# Parse geometry into X, Y, WIDTH, HEIGHT variables

# Calculate center
CENTER_X=$((X + WIDTH / 2))
CENTER_Y=$((Y + HEIGHT / 2))

# Move cursor via ydotool
ydotool mousemove --absolute -x $CENTER_X -y $CENTER_Y
```

**Tasks**:
- Replace `xdotool getactivewindow` with `qdbus` call
- Replace `xdotool getwindowgeometry` with `qdbus` call + parsing
- Replace `xdotool mousemove` with `ydotool mousemove`
- Add error handling for missing `ydotoold` daemon
- Add error handling for invalid window IDs or geometry

**Questions**:
- Should we keep the 10ms sleep delay?
- How should we handle errors (silent fail vs. logging)?
- Should we verify `ydotoold` is running before attempting movement?

### 3.2 Update `apply-scripts.sh`

**Changes Needed**:
- Replace `xdotool` check with `ydotool` check
- Add `ydotoold` daemon check/start
- Update installation instructions/comments
- Potentially add Wayland detection (if going hybrid X11/Wayland)

**Current Code** (lines 12-26):
```bash
# Check if xdotool is installed (required for cursor movement on X11)
if ! command -v xdotool &> /dev/null; then
    # ... install xdotool
fi
```

**New Code** (concept):
```bash
# Check if ydotool is installed (required for cursor movement on Wayland)
if ! command -v ydotool &> /dev/null; then
    # ... install ydotool
fi

# Check if ydotoold is running
if ! pgrep -x ydotoold > /dev/null; then
    # ... start ydotoold or provide instructions
fi
```

**Questions**:
- Should we auto-install `ydotool` or just check and warn?
- Should we auto-start `ydotoold` or just check and warn?
- Do we want Wayland detection, or assume Wayland-only?

## Phase 4: Testing & Validation

### 4.1 Test Scenarios

1. **Basic Functionality**:
   - Switch window left/right/up/down → cursor centers
   - Move window to screen → cursor centers

2. **Edge Cases**:
   - Multi-monitor setups
   - Windows at screen edges
   - Very small windows
   - Fullscreen windows
   - No active window

3. **Error Handling**:
   - `ydotoold` not running
   - Invalid window ID
   - Failed geometry query
   - Permission errors

### 4.2 Validation Checklist

- [ ] `ydotool` installed and accessible
- [ ] `ydotoold` daemon running
- [ ] Window ID retrieval works via `qdbus`
- [ ] Window geometry retrieval works via `qdbus`
- [ ] Cursor movement works via `ydotool`
- [ ] All 8 scripts (4 switch + 4 move) work correctly
- [ ] Multi-monitor setup works
- [ ] Error cases handled gracefully

## Open Questions for User

1. **Installation Method**: How should `ydotool` be installed?
   - Package manager (if available)?
   - Build from source?
   - Manual binary?

2. **Daemon Management**: How should `ydotoold` be managed?
   - Systemd user service (recommended)?
   - Manual start script?
   - Check and start on-demand?

3. **X11 Compatibility**: Do you need to support both X11 and Wayland?
   - If yes: Add detection logic (Option 4 from concepts)
   - If no: Wayland-only implementation (simpler)

4. **Error Handling**: How should errors be handled?
   - Silent fail (current behavior)?
   - Log to file?
   - Show notifications?

5. **Auto-Installation**: Should `apply-scripts.sh` auto-install `ydotool`?
   - Yes: Add installation logic
   - No: Just check and warn

## Next Steps

1. **User Decisions**: Answer open questions above
2. **Research**: Execute Phase 1 to identify exact `qdbus` methods
3. **Implementation**: Proceed with Phases 2-3 based on decisions
4. **Testing**: Execute Phase 4 validation

## Notes

- This plan implements **Option 1** from concepts-02.md
- The approach maintains the existing script architecture
- Only `kwin-center-cursor.sh` needs major changes
- `apply-scripts.sh` needs dependency check updates
- Action scripts (`kwin-switch-*.sh`, `kwin-move-screen-*.sh`) should not need changes






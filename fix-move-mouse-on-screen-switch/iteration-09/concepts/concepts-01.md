# Concepts: Screen Center Detection and Cursor Movement

## Problem Context

**Branch**: `fix-move-mouse-on-screen-switch`  
**Current Iteration**: `iteration-09`

### Core Challenge

We have a working ydotool workaround that can move the cursor to specific coordinates:
1. Move to (0,0) using `ydotool mousemove --absolute -x 0 -y 0`
2. Move relatively to target using `ydotool mousemove -x <target_x> -y <target_y>`

However, for the `kwin-move-screen-*.sh` scripts, we need to:
1. Determine which screen the window moved to
2. Get that screen's geometry (position and size)
3. Calculate its center coordinates
4. Move the cursor to those coordinates using the ydotool workaround

### Current State

- **Working**: ydotool v1.0.4 with relative movement workaround
- **Available Tools**: 
  - `kscreen-doctor -o` - provides screen geometry information
  - `qdbus org.kde.KWin /KWin activeOutputName` - gets current active output
  - `qdbus org.kde.KWin /KWin queryWindowInfo` - gets window information (may include screen info)
- **Scripts**: `kwin-move-screen-*.sh` scripts call `kwin-center-cursor.sh`, which currently centers on the window

## Solution Concepts

### Concept 1: Query Active Output After Window Move (Simplest)

**Approach**:
1. Execute KWin shortcut to move window (e.g., "Window One Screen to the Left")
2. Wait briefly for window to move (~50-100ms)
3. Query `qdbus org.kde.KWin /KWin activeOutputName` to get new active output
4. Parse `kscreen-doctor -o` output to find that output's geometry
5. Calculate center coordinates: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`
6. Use ydotool workaround to move cursor to center

**Pros**:
- Simple implementation - minimal logic required
- Uses existing D-Bus API that we know works
- Fast execution (single D-Bus call)
- Low complexity

**Cons**:
- Assumes active output changes to the screen the window moved to
- May fail if window moves but focus doesn't change
- Relies on KWin's focus behavior which may vary
- May not work if user clicks elsewhere between move and query

**Implementation Complexity**: Low  
**Reliability**: Medium  
**Recommended Order**: 2

---

### Concept 2: Parse Screen Layout and Calculate Neighbor (Most Reliable)

**Approach**:
1. Get current screen from `activeOutputName` before move
2. Parse all screens from `kscreen-doctor -o` to get geometry for all screens
3. Execute KWin shortcut to move window
4. Determine which screen is "left", "right", "up", or "down" from current screen based on geometry
5. Calculate center coordinates of target screen
6. Use ydotool workaround to move cursor to center

**Screen Neighbor Logic**:
- **Left**: Screen with maximum X coordinate that is still less than current screen's X
- **Right**: Screen with minimum X coordinate that is greater than current screen's X
- **Up**: Screen with maximum Y coordinate that is still less than current screen's Y
- **Down**: Screen with minimum Y coordinate that is greater than current screen's Y

**Pros**:
- Most reliable - doesn't depend on focus behavior
- Works regardless of whether focus changes
- Handles edge cases explicitly (no screen in direction, multiple screens)
- Deterministic logic based on screen geometry

**Cons**:
- More complex implementation - requires parsing and geometric calculations
- Need to handle edge cases (no screen in requested direction)
- May need to handle complex multi-monitor layouts (diagonal screens, etc.)
- Requires understanding screen layout topology

**Implementation Complexity**: Medium-High  
**Reliability**: High  
**Recommended Order**: 1

---

### Concept 3: Query Window's Output via D-Bus (Most Direct)

**Approach**:
1. Execute KWin shortcut to move window
2. Wait briefly for window to move
3. Query window information via D-Bus (`queryWindowInfo` or similar) to get window's current output/screen
4. Parse `kscreen-doctor -o` to get that screen's geometry
5. Calculate center coordinates
6. Use ydotool workaround to move cursor to center

**Pros**:
- Most direct approach - queries the window itself
- Doesn't depend on focus or active output
- Should work regardless of focus behavior
- Clean separation of concerns

**Cons**:
- Requires testing if `queryWindowInfo` includes screen/output information
- May not be available in KWin D-Bus API
- Unknown API - needs investigation
- May require additional D-Bus calls to get window ID first

**Implementation Complexity**: Medium (if API exists) / High (if needs investigation)  
**Reliability**: High (if API exists)  
**Recommended Order**: 3

---

### Concept 4: Hybrid Approach with Fallback (Balanced)

**Approach**:
1. Execute KWin shortcut to move window
2. Wait briefly for window to move
3. Try to query window's output via D-Bus (Concept 3)
4. If that fails or doesn't return screen info, fall back to Concept 1 (query activeOutputName)
5. If that also fails, fall back to Concept 2 (calculate neighbor)
6. Parse screen geometry and calculate center
7. Use ydotool workaround to move cursor

**Pros**:
- Combines strengths of multiple approaches
- Has fallback mechanisms for reliability
- Can adapt to different scenarios
- More robust overall

**Cons**:
- Most complex implementation
- Multiple code paths to maintain
- May be overkill if simpler approach works
- Slower execution if fallbacks are needed

**Implementation Complexity**: High  
**Reliability**: Very High  
**Recommended Order**: 4

---

### Concept 5: Separate Scripts for Window vs Screen Centering

**Approach**:
1. Keep `kwin-center-cursor.sh` for window centering (used by `kwin-switch-*.sh` scripts)
2. Create new `kwin-center-screen.sh` script specifically for screen centering
3. Update `kwin-move-screen-*.sh` scripts to call `kwin-center-screen.sh` instead
4. Implement one of Concepts 1-4 in `kwin-center-screen.sh`

**Pros**:
- Clear separation of concerns
- Easier to maintain - each script has single responsibility
- Can optimize each script for its use case
- Easier to test independently
- Can use different approaches for window vs screen centering

**Cons**:
- More scripts to maintain
- Potential code duplication (screen geometry parsing, ydotool workaround)
- Need to update 4 scripts (`kwin-move-screen-*.sh`) to use new script

**Implementation Complexity**: Medium (depends on chosen detection method)  
**Reliability**: Same as chosen detection method  
**Recommended Order**: 5 (architectural decision, can combine with any Concept 1-4)

---

## Screen Geometry Parsing Strategy

All concepts require parsing `kscreen-doctor -o` output. The format is:
```
Output: 1 eDP-1 enabled connected priority 1 Panel Modes: ... Geometry: 891,1080 1920x1200 Scale: 1 Rotation: 1 ...
```

**Parsing Approach**:
- Extract line containing output name (e.g., "eDP-1")
- Extract geometry string using regex or awk/sed: `Geometry: X,Y WIDTHxHEIGHT`
- Parse X, Y, WIDTH, HEIGHT values
- Calculate center: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`

**Example**:
- Screen: eDP-1
- Geometry: `891,1080 1920x1200`
- Center X: `891 + (1920 / 2) = 1851`
- Center Y: `1080 + (1200 / 2) = 1680`

## Recommendations

### Primary Recommendation: Concept 2 (Parse Screen Layout and Calculate Neighbor)

**Rationale**:
- Most reliable - doesn't depend on focus behavior or D-Bus API availability
- Deterministic logic based on screen geometry
- Handles edge cases explicitly
- Works regardless of whether focus changes after window move

**Implementation Steps**:
1. Create helper function to parse `kscreen-doctor -o` output and extract screen geometries
2. Create helper function to get current screen from `activeOutputName`
3. Create helper function to find neighbor screen based on direction (left/right/up/down)
4. Create helper function to calculate center coordinates from geometry
5. Integrate with ydotool workaround
6. Update `kwin-center-cursor.sh` or create `kwin-center-screen.sh` (Concept 5)

### Secondary Recommendation: Concept 1 (Query Active Output) + Concept 5 (Separate Scripts)

**Rationale**:
- Simpler implementation if it works reliably
- Concept 5 (separate scripts) provides clean architecture
- Can always upgrade to Concept 2 if Concept 1 proves unreliable

**Implementation Steps**:
1. Create `kwin-center-screen.sh` script
2. Implement Concept 1 (query activeOutputName after move)
3. Test thoroughly - if unreliable, upgrade to Concept 2
4. Update `kwin-move-screen-*.sh` scripts to use new script

### Testing Recommendation: Concept 3 First

**Rationale**:
- If `queryWindowInfo` includes screen information, it's the most direct approach
- Worth testing before implementing more complex solutions
- Can inform decision between Concept 1 and Concept 2

**Testing Steps**:
1. Move window to different screen
2. Query `qdbus org.kde.KWin /KWin queryWindowInfo` (may need window ID)
3. Inspect output for screen/output information
4. If available, Concept 3 is viable; if not, proceed with Concept 1 or 2

## Edge Cases to Consider

1. **No screen in requested direction**: Script should handle gracefully (maybe no-op or error message)
2. **Multiple screens in same direction**: Use closest screen (minimum distance)
3. **Single monitor setup**: Script should still work (window stays on same screen)
4. **Screen layout changes**: Script should query fresh geometry each time (or cache with invalidation)
5. **Window already on target screen**: May need to detect and handle
6. **Screen rotation/transformation**: Geometry parsing should account for rotation if needed

## Questions for User

1. **Architecture**: Do you prefer Concept 5 (separate scripts) or modifying `kwin-center-cursor.sh` to handle both cases?
2. **Reliability vs Simplicity**: Do you prefer Concept 2 (more reliable, more complex) or Concept 1 (simpler, may be less reliable)?
3. **Testing**: Should we test Concept 3 first to see if window output info is available via D-Bus?
4. **Edge Cases**: How should we handle cases where there's no screen in the requested direction?
5. **Performance**: Is it acceptable to call `kscreen-doctor` on every script execution, or should we cache screen information?

## Next Steps

1. User decides on preferred concept(s)
2. Test Concept 3 (queryWindowInfo) if user wants to explore that option
3. Implement chosen concept
4. Test with various screen layouts and edge cases
5. Integrate with existing scripts


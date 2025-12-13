# Understanding: Determining Screen Center Coordinates for Cursor Movement

## Problem Context

**Branch**: `fix-move-mouse-on-screen-switch`  
**Current Iteration**: `iteration-09`

### Core Problem

We have a working ydotool workaround that can move the cursor to specific coordinates using a two-step process:
1. Move to (0,0) using `ydotool mousemove --absolute -x 0 -y 0`
2. Move relatively to target using `ydotool mousemove -x <target_x> -y <target_y>`

However, we need to determine **which screen** we're moving to and calculate its **center coordinates** so we can move the cursor to the correct location.

### Current Script Structure

**Scripts Involved**:
- `kwin-center-cursor.sh` - Currently centers cursor on active window (uses xdotool)
- `kwin-switch-*.sh` (4 scripts) - Switch windows in different directions, then center cursor
- `kwin-move-screen-*.sh` (4 scripts) - Move windows to different screens, then center cursor

**Current Behavior**:
- `kwin-move-screen-*.sh` scripts move a window to a different screen (left, right, up, down)
- They then call `kwin-center-cursor.sh` to center the cursor
- Currently, `kwin-center-cursor.sh` centers on the **window**, but for screen-moving scripts, we want to center on the **screen** instead

### User's Request

The user wants to understand how to:
1. Determine which screen we're moving to (when using `kwin-move-screen-*.sh` scripts)
2. Get that screen's geometry (position and size)
3. Calculate the center coordinates of that screen
4. Use those coordinates with the ydotool workaround to move the cursor

## Screen Information Discovery

### 1. Getting Screen Information via `kscreen-doctor`

**Tool**: `kscreen-doctor -o` (part of KDE's kscreen package)

**Output Format**:
```
Output: 1 eDP-1 enabled connected priority 1 Panel Modes: ... Geometry: 891,1080 1920x1200 Scale: 1 Rotation: 1 ...
Output: 2 HDMI-A-1 enabled connected priority 3 HDMI Modes: ... Geometry: 1920,0 1920x1080 Scale: 1 Rotation: 1 ...
Output: 3 DP-5 enabled connected priority 2 DisplayPort Modes: ... Geometry: 0,0 1920x1080 Scale: 1 Rotation: 1 ...
```

**Key Information Extracted**:
- **Output Name**: eDP-1, HDMI-A-1, DP-5
- **Geometry**: Format is `X,Y WIDTHxHEIGHT` (e.g., "891,1080 1920x1200")
  - Position: X,Y coordinates in global coordinate system
  - Size: WIDTHxHEIGHT resolution

**Current Monitor Layout** (from testing):
- **DP-5**: Geometry `0,0 1920x1080` → Center: (960, 540)
- **HDMI-A-1**: Geometry `1920,0 1920x1080` → Center: (2880, 540)
- **eDP-1**: Geometry `891,1080 1920x1200` → Center: (1851, 1680)

### 2. Getting Active Output via KWin D-Bus

**Method**: `qdbus org.kde.KWin /KWin activeOutputName`

**Returns**: Output name string (e.g., "HDMI-A-1")

**Use Case**: Can determine which screen currently has focus/active window

### 3. Getting Window Information via KWin D-Bus

**Method**: `qdbus org.kde.KWin /KWin queryWindowInfo`

**Returns**: QVariantMap with window information (may include output/screen information)

**Status**: Needs testing to see if it includes screen/output name

## Challenge: Determining Target Screen

### Problem Statement

When a script calls `kwin-move-screen-left.sh`, `kwin-move-screen-right.sh`, `kwin-move-screen-up.sh`, or `kwin-move-screen-down.sh`:

1. **Window moves** to a different screen (via KWin shortcut)
2. **We need to determine** which screen the window moved to
3. **We need to get** that screen's geometry
4. **We need to calculate** the center coordinates
5. **We need to move** the cursor to those coordinates

### Approaches to Determine Target Screen

#### Approach 1: Query Active Output After Window Move

**Process**:
1. Execute KWin shortcut to move window (e.g., "Window One Screen to the Left")
2. Wait briefly for window to move
3. Query `qdbus org.kde.KWin /KWin activeOutputName` to get new active output
4. Parse `kscreen-doctor -o` output to find that output's geometry
5. Calculate center coordinates

**Considerations**:
- Assumes active output changes to the screen the window moved to
- May not work if window moves but focus doesn't change
- Requires parsing `kscreen-doctor` output

#### Approach 2: Parse Screen Layout and Calculate Neighbor

**Process**:
1. Get current screen from `activeOutputName`
2. Parse all screens from `kscreen-doctor -o` to get geometry for all screens
3. Determine which screen is "left", "right", "up", or "down" from current screen based on geometry
4. Calculate center coordinates of target screen

**Considerations**:
- Requires understanding screen layout (which screen is where)
- Need to handle edge cases (no screen in that direction)
- More complex logic but more reliable

**Screen Neighbor Logic**:
- **Left**: Screen with maximum X coordinate that is still less than current screen's X
- **Right**: Screen with minimum X coordinate that is greater than current screen's X
- **Up**: Screen with maximum Y coordinate that is still less than current screen's Y
- **Down**: Screen with minimum Y coordinate that is greater than current screen's Y

#### Approach 3: Get Window's Output After Move

**Process**:
1. Execute KWin shortcut to move window
2. Query window information via D-Bus to get window's current output/screen
3. Parse `kscreen-doctor -o` to get that screen's geometry
4. Calculate center coordinates

**Considerations**:
- Requires finding a way to get window's output/screen from D-Bus
- May need to test if `queryWindowInfo` includes screen information
- Most direct approach if available

## Screen Geometry Parsing

### Parsing `kscreen-doctor` Output

**Format**: `Geometry: X,Y WIDTHxHEIGHT`

**Example**: `Geometry: 891,1080 1920x1200`

**Parsing Strategy**:
1. Extract line containing output name
2. Extract geometry string using regex or string parsing
3. Parse X, Y, WIDTH, HEIGHT values
4. Calculate center: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`

**Example Calculation**:
- Screen: eDP-1
- Geometry: `891,1080 1920x1200`
- Center X: `891 + (1920 / 2) = 891 + 960 = 1851`
- Center Y: `1080 + (1200 / 2) = 1080 + 600 = 1680`
- Center coordinates: (1851, 1680)

## Integration with ydotool Workaround

### Current Workaround Process

1. Move to (0,0): `ydotool mousemove --absolute -x 0 -y 0`
2. Move relatively: `ydotool mousemove -x <target_x> -y <target_y>`

### Using Screen Center Coordinates

**Process**:
1. Determine target screen (using one of the approaches above)
2. Get screen geometry from `kscreen-doctor -o`
3. Calculate center coordinates: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`
4. Apply workaround:
   ```bash
   ydotool mousemove --absolute -x 0 -y 0
   sleep 0.05
   ydotool mousemove -x $CENTER_X -y $CENTER_Y
   ```

## Key Questions to Resolve

### 1. How to Determine Target Screen?

**Question**: After moving a window to a different screen, how do we reliably determine which screen it moved to?

**Options**:
- Query `activeOutputName` after move (assumes focus follows window)
- Parse screen layout and calculate neighbor based on direction
- Query window information to get window's current output

**Recommendation**: Test `queryWindowInfo` first to see if it includes screen/output information. If not, use `activeOutputName` approach.

### 2. Screen Layout Parsing

**Question**: How should we parse `kscreen-doctor` output reliably?

**Considerations**:
- Output format may vary
- Need to handle multiple screens
- Need to extract geometry accurately
- May need to handle edge cases (disabled screens, etc.)

**Recommendation**: Use regex or awk/sed to parse geometry string from output lines.

### 3. Edge Cases

**Questions**:
- What if there's no screen in the requested direction?
- What if multiple screens are in the same direction?
- What if screen layout changes dynamically?

**Considerations**:
- Need to handle single-monitor setups
- Need to handle complex multi-monitor layouts
- May need to handle screen rotation/transformation

### 4. Performance Considerations

**Questions**:
- Is `kscreen-doctor` fast enough to call on every script execution?
- Should we cache screen information?
- How often does screen layout change?

**Considerations**:
- `kscreen-doctor` may have some overhead
- Screen layout typically doesn't change during session
- Caching could improve performance but adds complexity

## Implementation Strategy

### Proposed Approach

1. **Create helper function** to get screen geometry:
   - Parse `kscreen-doctor -o` output
   - Extract geometry for a given output name
   - Return X, Y, WIDTH, HEIGHT

2. **Create helper function** to get target screen:
   - For `kwin-move-screen-*.sh` scripts: determine target screen based on direction
   - Query `activeOutputName` after window move
   - Or parse screen layout to find neighbor

3. **Create helper function** to calculate center coordinates:
   - Take screen geometry (X, Y, WIDTH, HEIGHT)
   - Calculate center: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`

4. **Update `kwin-center-cursor.sh`**:
   - For window-switching scripts: center on window (current behavior)
   - For screen-moving scripts: center on screen (new behavior)
   - Use ydotool workaround with calculated coordinates

### Alternative: Separate Scripts

**Option**: Create separate script `kwin-center-screen.sh` for screen centering, keep `kwin-center-cursor.sh` for window centering.

**Advantages**:
- Clear separation of concerns
- Easier to maintain
- Can optimize each for its use case

**Disadvantages**:
- More scripts to maintain
- Potential code duplication

## Testing Requirements

### Test Scenarios

1. **Single Monitor**: Verify script works with one screen
2. **Two Monitors**: Test moving window left/right between two screens
3. **Three Monitors**: Test moving window in all directions (up, down, left, right)
4. **Different Layouts**: Test with screens in different positions (side-by-side, stacked, etc.)
5. **Edge Cases**: 
   - No screen in requested direction
   - Window already on target screen
   - Screen layout changes during session

### Verification Steps

1. Execute `kwin-move-screen-*.sh` script
2. Verify window moves to correct screen
3. Verify cursor moves to center of target screen
4. Verify cursor position is accurate (within acceptable tolerance)

## Questions for Clarification

1. **Screen vs Window Centering**:
   - Should `kwin-move-screen-*.sh` scripts center on the **screen** or the **window**?
   - User's request suggests centering on the **screen** (center of the screen we're moving to)

2. **Screen Detection Method**:
   - Which approach should we use to determine target screen?
   - Should we test `queryWindowInfo` first to see if it includes screen information?

3. **Parsing Strategy**:
   - Should we parse `kscreen-doctor` output, or is there a better D-Bus method?
   - Are there any concerns about calling `kscreen-doctor` on every script execution?

4. **Error Handling**:
   - What should happen if we can't determine the target screen?
   - What should happen if screen layout parsing fails?

5. **Performance**:
   - Is it acceptable to call `kscreen-doctor` on every script execution?
   - Should we implement caching for screen information?

## Understanding Summary

**Core Challenge**: Determine which screen a window moved to and calculate its center coordinates for cursor movement.

**Key Findings**:
1. `kscreen-doctor -o` provides screen geometry information (position and size)
2. `qdbus org.kde.KWin /KWin activeOutputName` can get current active output
3. Screen geometry format: `X,Y WIDTHxHEIGHT` (e.g., "891,1080 1920x1200")
4. Center calculation: `CENTER_X = X + WIDTH / 2`, `CENTER_Y = Y + HEIGHT / 2`

**Approach Options**:
1. Query `activeOutputName` after window move (assumes focus follows window)
2. Parse screen layout and calculate neighbor based on direction
3. Query window information to get window's current output (needs testing)

**Next Steps**:
1. Test if `queryWindowInfo` includes screen/output information
2. Implement screen geometry parsing from `kscreen-doctor` output
3. Implement target screen detection logic
4. Integrate with ydotool workaround for cursor movement


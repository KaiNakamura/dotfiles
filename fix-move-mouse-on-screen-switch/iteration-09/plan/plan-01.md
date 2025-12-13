# Implementation Plan: Concept 2 - Parse Screen Layout and Calculate Neighbor

## Problem Context

**Branch**: `fix-move-mouse-on-screen-switch`  
**Current Iteration**: `iteration-09`  
**Concept**: Concept 2 - Parse Screen Layout and Calculate Neighbor (Most Reliable)

### Current State

- Four `kwin-move-screen-*.sh` scripts (left, right, up, down) that:
  1. Execute KWin shortcut to move window to different screen
  2. Call `kwin-center-cursor.sh` to center cursor
- `kwin-center-cursor.sh` currently centers cursor on the **window** (using xdotool)
- We need to center cursor on the **screen** instead for screen-moving scripts
- Working ydotool workaround available: `workaround-relative.sh` (moves to 0,0 then relative to target)
- **Problem**: KWin shortcuts cycle between screens (e.g., moving left from leftmost screen wraps to rightmost screen)
- **Requirement**: Prevent cycling - if no screen exists in requested direction, don't move window/cursor

### Goal

Implement Concept 2 to:
1. **Before move**: Check if a neighbor screen exists in the requested direction
2. **Only if neighbor exists**: Execute KWin shortcut to move window
3. Determine which screen the window moved to (should match predicted neighbor)
4. Get that screen's geometry and calculate center coordinates
5. Move cursor to screen center using ydotool workaround
6. **If no neighbor exists**: Do nothing (no-op) - prevent cycling behavior

## High-Level Approach

### Core Strategy

1. **Before window move**: 
   - Get current screen from `activeOutputName`
   - Parse screen layout: Get all screen geometries from `kscreen-doctor -o`
   - **Check if neighbor exists**: Calculate if a neighbor screen exists in requested direction
2. **Conditional window move**: 
   - **If neighbor exists**: Execute KWin shortcut to move window
   - **If no neighbor**: Exit early (no-op) - prevent cycling behavior
3. **After window move** (only if neighbor existed):
   - Verify target screen matches predicted neighbor (optional safety check)
   - Calculate center coordinates of target screen
   - Move cursor using ydotool workaround to center

### Screen Neighbor Logic

- **Left**: Screen with maximum X coordinate that is still less than current screen's X
- **Right**: Screen with minimum X coordinate that is greater than current screen's X
- **Up**: Screen with maximum Y coordinate that is still less than current screen's Y
- **Down**: Screen with minimum Y coordinate that is greater than current screen's Y

## Implementation Components

### 1. Screen Geometry Parsing Function

**Purpose**: Parse `kscreen-doctor -o` output to extract screen geometries

**Input**: Output name (e.g., "eDP-1", "HDMI-A-1")

**Output**: X, Y, WIDTH, HEIGHT values

**Format to parse**: `Geometry: X,Y WIDTHxHEIGHT` (e.g., "Geometry: 891,1080 1920x1200")

**Questions for user**:
- Should we parse all screens at once and cache, or parse on-demand?
- How should we handle parsing errors or missing screens?
- Should we support disabled screens or only enabled/connected ones?

### 2. Current Screen Detection Function

**Purpose**: Get the current active screen name

**Method**: `qdbus org.kde.KWin /KWin activeOutputName`

**Output**: Screen name string (e.g., "HDMI-A-1")

**Questions for user**:
- Should we call this before or after the window move?
- How should we handle if activeOutputName fails or returns empty?

### 3. Neighbor Screen Calculation Function

**Purpose**: Find the neighbor screen in a given direction (or determine if none exists)

**Input**: 
- Current screen name
- Direction (left/right/up/down)
- All screen geometries

**Logic**:
- Get current screen's geometry
- Filter screens based on direction criteria
- Return target screen name if found, or empty/null if no neighbor exists

**Return Values**:
- **Success**: Target screen name (e.g., "HDMI-A-1")
- **No neighbor**: Empty string or special value indicating no screen in direction

**Edge cases to handle**:
- **No screen in requested direction**: Return empty/null (this prevents cycling)
- **Multiple screens in same direction**: Use closest one (minimum distance)
- **Single monitor setup**: Will always return no neighbor (prevents cycling)

**Behavior**:
- If function returns no neighbor, the script should exit early without executing KWin shortcut
- This prevents the cycling behavior where KWin wraps around to the opposite side

### 4. Center Coordinate Calculation Function

**Purpose**: Calculate center coordinates from screen geometry

**Input**: X, Y, WIDTH, HEIGHT

**Output**: CENTER_X, CENTER_Y

**Formula**: 
- `CENTER_X = X + WIDTH / 2`
- `CENTER_Y = Y + HEIGHT / 2`

**Questions for user**:
- Should we round to integers or keep decimals?
- Any special handling for rotated screens?

### 5. Cursor Movement Integration

**Purpose**: Move cursor to screen center using ydotool workaround

**Method**: Use existing `workaround-relative.sh` or integrate directly

**Questions for user**:
- Should we:
  - Call `workaround-relative.sh` script?
  - Integrate the workaround logic directly into the new script?
  - Create a reusable function that both can use?

### 6. Script Architecture Decision

**Options**:

**Option A**: Create new `kwin-center-screen.sh` script
- Keep `kwin-center-cursor.sh` for window centering
- Update all 4 `kwin-move-screen-*.sh` scripts to call new script
- Clear separation of concerns

**Option B**: Modify `kwin-center-cursor.sh` to accept parameters
- Add parameter to specify window vs screen centering
- Update `kwin-move-screen-*.sh` scripts to pass parameter
- Single script handles both cases

**Option C**: Modify `kwin-center-cursor.sh` to detect context
- Detect if called from screen-moving script vs window-switching script
- Automatically choose appropriate behavior
- No changes needed to calling scripts

**Questions for user**:
- Which architecture do you prefer?
- Do you want to keep window centering functionality separate?

## Detailed Implementation Steps

### Step 1: Create Helper Functions

Create functions for:
- [ ] Parsing `kscreen-doctor -o` output
- [ ] Getting current screen name
- [ ] Finding neighbor screen
- [ ] Calculating center coordinates

**Location**: New script or shared library?

### Step 2: Implement Screen Centering Logic

Implement the main logic:
- [ ] Get current screen before move
- [ ] Parse all screen geometries
- [ ] **Check if neighbor screen exists in requested direction**
- [ ] **If no neighbor exists: exit early (no-op)**
- [ ] **If neighbor exists: continue with move**
- [ ] Execute KWin shortcut (only if neighbor exists)
- [ ] Calculate center coordinates of target screen
- [ ] Move cursor using ydotool workaround

**Location**: New `kwin-center-screen.sh` or modified `kwin-center-cursor.sh`?

**Key Change**: The script now needs to check for neighbor existence BEFORE executing the KWin shortcut

### Step 3: Update Move-Screen Scripts

Update all 4 scripts:
- [ ] `kwin-move-screen-left.sh`
- [ ] `kwin-move-screen-right.sh`
- [ ] `kwin-move-screen-up.sh`
- [ ] `kwin-move-screen-down.sh`

**Changes**: 
- Move KWin shortcut execution INTO the new screen centering script/function
- The script/function will check for neighbor existence BEFORE executing shortcut
- If no neighbor exists, shortcut is never executed (prevents cycling)
- If neighbor exists, shortcut executes and cursor moves to screen center

### Step 4: Error Handling

Implement error handling for:
- [ ] `kscreen-doctor` command failure
- [ ] `activeOutputName` failure
- [ ] **No screen in requested direction** (expected case - exit gracefully, no error)
- [ ] Parsing errors
- [ ] ydotool workaround failure
- [ ] KWin shortcut execution failure

**Note**: "No screen in requested direction" is now an expected case that should exit silently (no-op), not an error condition

### Step 5: Testing

Test scenarios:
- [ ] Single monitor setup (should not move when trying to move left/right/up/down)
- [ ] Two monitors (side-by-side)
  - [ ] Moving left from leftmost screen should do nothing (no-op)
  - [ ] Moving right from rightmost screen should do nothing (no-op)
- [ ] Three monitors (various layouts)
  - [ ] Test all directions from edge screens
  - [ ] Verify no cycling occurs
- [ ] Edge cases:
  - [ ] No screen in requested direction (should exit silently, no error)
  - [ ] Multiple screens in same direction (should use closest)
- [ ] Verify cursor moves to correct screen center when move actually occurs
- [ ] Verify cursor does NOT move when no neighbor exists (prevents cycling)

## Open Questions

1. **Architecture**: Option A (new script), Option B (parameterized), or Option C (auto-detect)?
2. **Script structure**: Should the new script/function:
   - Accept direction as parameter and execute KWin shortcut internally?
   - Or should the move-screen scripts check for neighbor first, then call a separate centering function?
3. **Performance**: Should we cache screen geometry or query every time?
4. **Integration**: Use `workaround-relative.sh` script or integrate logic directly?
5. **Multiple screens in same direction**: Use closest one (minimum distance) - confirmed?
6. **Timing**: Should we add a delay after window move before querying screen?
7. **Verification**: Should we verify the window actually moved to the predicted screen, or trust the calculation?

## Updated Flow Diagram

### Current Flow (Problematic)
```
kwin-move-screen-left.sh:
  1. Execute KWin shortcut (always executes, even if no screen left)
  2. Call kwin-center-cursor.sh (centers on window, not screen)
  → Problem: Cycles to rightmost screen if already on leftmost
```

### New Flow (Prevents Cycling)
```
kwin-move-screen-left.sh:
  1. Get current screen
  2. Parse all screen geometries
  3. Check if neighbor screen exists to the left
  4. IF neighbor exists:
     a. Execute KWin shortcut
     b. Calculate target screen center
     c. Move cursor to screen center
  5. IF no neighbor:
     a. Exit silently (no-op)
  → Result: No cycling, window stays on current screen
```

## Next Steps

1. User answers open questions (especially #2 about script structure)
2. Refine plan based on user preferences
3. Implement chosen approach
4. Test thoroughly (especially cycling prevention)
5. Update documentation if needed


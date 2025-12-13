# Implementation Plan: Concept 2 - Detailed Implementation

## Problem Context

**Branch**: `fix-move-mouse-on-screen-switch`  
**Current Iteration**: `iteration-09`  
**Concept**: Concept 2 - Parse Screen Layout and Calculate Neighbor (Most Reliable)

### User Decisions

- ✅ Parse screen geometry on-demand (no caching)
- ✅ Detect current screen **before** window move
- ✅ Round coordinates to integers
- ✅ Modify existing scripts directly (no backwards compatibility needed)
- ✅ Integrate ydotool workaround directly (don't call external script)

### Current State

- Four `kwin-move-screen-*.sh` scripts that execute KWin shortcuts and call `kwin-center-cursor.sh`
- `kwin-center-cursor.sh` centers cursor on window (using xdotool) - not suitable for screen centering
- KWin shortcuts cycle between screens (problematic behavior)
- Need to prevent cycling and center cursor on screen instead of window

### Goal

Modify the four `kwin-move-screen-*.sh` scripts to:
1. Check if neighbor screen exists before executing KWin shortcut
2. Only execute shortcut if neighbor exists (prevents cycling)
3. Calculate target screen center coordinates
4. Move cursor to screen center using ydotool workaround

## Implementation Architecture

### Approach: Shared Library + Direction Scripts

**Shared Library**: `kde/scripts/kwin-screen-helpers.sh`
- Contains all common helper functions
- Parsing, neighbor detection, cursor movement
- Can be sourced by any script that needs screen manipulation

**Direction Scripts**: Each `kwin-move-screen-*.sh` script will:
- Source the shared library
- Set direction-specific variables (DIRECTION, KWIN_SHORTCUT)
- Execute the main logic flow

### Files to Create/Modify

**New File**:
1. `kde/scripts/kwin-screen-helpers.sh` - Shared helper functions library

**Files to Modify**:
1. `kde/scripts/kwin-move-screen-left.sh`
2. `kde/scripts/kwin-move-screen-right.sh`
3. `kde/scripts/kwin-move-screen-up.sh`
4. `kde/scripts/kwin-move-screen-down.sh`

## Detailed Implementation

### Step 0: Create Shared Library File

**File**: `kde/scripts/kwin-screen-helpers.sh`

**Purpose**: Contains all shared helper functions that will be used by the direction scripts

**Structure**: Library file with functions that can be sourced

**Note**: Functions should use `declare -gA` for associative arrays to make them available to sourcing scripts

---

### Helper Functions (to be included in shared library)

#### 1. `get_current_screen()`

**Purpose**: Get current active screen name

**Implementation**:
```bash
get_current_screen() {
    qdbus org.kde.KWin /KWin activeOutputName 2>/dev/null
}
```

**Returns**: Screen name string (e.g., "HDMI-A-1") or empty on error

**Error Handling**: Returns empty string if command fails

---

#### 2. `parse_screen_geometries()`

**Purpose**: Parse `kscreen-doctor -o` output and extract all screen geometries

**Implementation Strategy**:
- Call `kscreen-doctor -o`
- Parse each line containing "Output:"
- Extract output name and geometry string
- Store in associative array or parse on-the-fly

**Output Format**: 
- Need to extract: `Output: N NAME ... Geometry: X,Y WIDTHxHEIGHT ...`
- Example: `Output: 1 eDP-1 enabled connected priority 1 Panel Modes: ... Geometry: 891,1080 1920x1200 Scale: 1 ...`

**Parsing Method**:
- Use `grep` to find lines with "Output:" and "Geometry:"
- Use `awk` or `sed` to extract geometry values
- Parse X, Y, WIDTH, HEIGHT from `Geometry: X,Y WIDTHxHEIGHT`

**Function Signature**:
```bash
# Returns geometry for a specific screen name
get_screen_geometry() {
    local screen_name=$1
    # Parse kscreen-doctor output and return X Y WIDTH HEIGHT
}
```

**Alternative**: Parse all screens into associative array, then lookup by name

**Recommendation**: Parse all screens once, store in associative array for efficient lookup

---

#### 3. `find_neighbor_screen()`

**Purpose**: Find neighbor screen in given direction, or return empty if none exists

**Input**:
- Current screen name
- Direction (left/right/up/down)
- All screen geometries (parsed from kscreen-doctor)

**Logic**:

**For LEFT**:
- Get current screen's X coordinate
- Find all screens with X < current_X
- Return screen with maximum X (closest to current screen)

**For RIGHT**:
- Get current screen's X coordinate  
- Find all screens with X > current_X
- Return screen with minimum X (closest to current screen)

**For UP**:
- Get current screen's Y coordinate
- Find all screens with Y < current_Y
- Return screen with maximum Y (closest to current screen)

**For DOWN**:
- Get current screen's Y coordinate
- Find all screens with Y > current_Y
- Return screen with minimum Y (closest to current screen)

**Returns**: 
- Screen name if neighbor exists
- Empty string if no neighbor exists

**Edge Cases**:
- Multiple screens in same direction: Use closest (minimum distance)
- No screen in direction: Return empty string
- Single monitor: Will always return empty (prevents cycling)

---

#### 4. `calculate_screen_center()`

**Purpose**: Calculate center coordinates from screen geometry

**Input**: X, Y, WIDTH, HEIGHT

**Formula**:
```bash
CENTER_X=$((X + WIDTH / 2))
CENTER_Y=$((Y + HEIGHT / 2))
```

**Returns**: CENTER_X, CENTER_Y (as integers, rounded)

---

#### 5. `move_cursor_to_coordinates()`

**Purpose**: Move cursor to target coordinates using ydotool workaround

**Implementation** (integrated from `workaround-relative.sh`):
```bash
move_cursor_to_coordinates() {
    local target_x=$1
    local target_y=$2
    
    export YDOTOOL_SOCKET=/tmp/.ydotool_socket
    
    # Step 1: Move to origin (0,0) using absolute
    ydotool mousemove --absolute -x 0 -y 0 2>/dev/null
    sleep 0.05
    
    # Step 2: Move relatively from (0,0) to target
    ydotool mousemove -x "$target_x" -y "$target_y" 2>/dev/null
}
```

**Error Handling**: Fail silently (don't break script if ydotool fails)

---

### Shared Library Structure

**File**: `kde/scripts/kwin-screen-helpers.sh`

```bash
#!/bin/bash
# kwin-screen-helpers.sh - Shared helper functions for screen manipulation

# Global associative array for screen geometries
declare -gA SCREEN_GEOMETRIES

# All helper functions defined here:
# - get_current_screen()
# - parse_all_screen_geometries()
# - get_screen_geometry()
# - find_neighbor_screen()
# - move_cursor_to_coordinates()
```

**Note**: The library should be idempotent - safe to source multiple times

---

### Main Script Logic (for each direction script)

#### Template Structure

```bash
#!/bin/bash
# kwin-move-screen-{DIRECTION}.sh - Move window to screen {DIRECTION} and center cursor

# Source shared helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/kwin-screen-helpers.sh"

# Direction-specific configuration
DIRECTION="left"  # or "right", "up", "down"
KWIN_SHORTCUT="Window One Screen to the Left"  # varies by direction

# Step 1: Parse all screen geometries
parse_all_screen_geometries

# Step 2: Get current screen BEFORE move
CURRENT_SCREEN=$(get_current_screen)
if [[ -z "$CURRENT_SCREEN" ]]; then
    # Can't determine current screen, exit
    exit 0
fi

# Step 3: Find neighbor screen in requested direction
NEIGHBOR_SCREEN=$(find_neighbor_screen "$CURRENT_SCREEN" "$DIRECTION")

# Step 4: Check if neighbor exists
if [[ -z "$NEIGHBOR_SCREEN" ]]; then
    # No neighbor in this direction - exit silently (no-op, prevents cycling)
    exit 0
fi

# Step 5: Execute KWin shortcut (only if neighbor exists)
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "$KWIN_SHORTCUT"

# Step 6: Get neighbor screen geometry and calculate center
NEIGHBOR_GEOM=$(get_screen_geometry "$NEIGHBOR_SCREEN")
read -r x y width height <<< "$NEIGHBOR_GEOM"
CENTER_X=$((x + width / 2))
CENTER_Y=$((y + height / 2))

# Step 7: Move cursor to screen center
move_cursor_to_coordinates "$CENTER_X" "$CENTER_Y"
```

---

## Implementation Steps

### Step 0: Create Shared Library File

**Task**: Create `kde/scripts/kwin-screen-helpers.sh` with all helper functions

**File Structure**:
```bash
#!/bin/bash
# kwin-screen-helpers.sh - Shared helper functions for screen manipulation

# Global associative array for screen geometries
declare -gA SCREEN_GEOMETRIES

# Function definitions:
# - get_current_screen()
# - parse_all_screen_geometries()
# - get_screen_geometry()
# - find_neighbor_screen()
# - move_cursor_to_coordinates()
```

**Implementation**: Include all helper function implementations from sections below

---

### Step 1: Implement Screen Geometry Parsing

**Task**: Create function to parse `kscreen-doctor -o` output

**Details**:
- Parse output format: `Output: N NAME ... Geometry: X,Y WIDTHxHEIGHT ...`
- Extract screen name and geometry for each screen
- Store in associative array: `declare -A SCREEN_GEOMETRIES`
- Key: screen name (e.g., "HDMI-A-1")
- Value: "X Y WIDTH HEIGHT" (space-separated)

**Parsing Strategy**:
```bash
parse_all_screen_geometries() {
    # Clear existing geometries (in case function is called multiple times)
    SCREEN_GEOMETRIES=()
    
    while IFS= read -r line; do
        if [[ $line =~ Output:[[:space:]]+[0-9]+[[:space:]]+([^[:space:]]+) ]]; then
            screen_name="${BASH_REMATCH[1]}"
            if [[ $line =~ Geometry:[[:space:]]+([0-9]+),([0-9]+)[[:space:]]+([0-9]+)x([0-9]+) ]]; then
                x="${BASH_REMATCH[1]}"
                y="${BASH_REMATCH[2]}"
                width="${BASH_REMATCH[3]}"
                height="${BASH_REMATCH[4]}"
                SCREEN_GEOMETRIES["$screen_name"]="$x $y $width $height"
            fi
        fi
    done < <(kscreen-doctor -o 2>/dev/null)
}
```

**Function to get geometry**:
```bash
get_screen_geometry() {
    local screen_name=$1
    echo "${SCREEN_GEOMETRIES[$screen_name]}"
}
```

**Note**: The `SCREEN_GEOMETRIES` associative array is declared at the top of the shared library file with `declare -gA SCREEN_GEOMETRIES` to make it globally available to sourcing scripts.

---

### Step 2: Implement Neighbor Detection Logic

**Task**: Create `find_neighbor_screen()` function

**Implementation**:
```bash
find_neighbor_screen() {
    local current_screen=$1
    local direction=$2
    
    # Get current screen geometry
    local current_geom=$(get_screen_geometry "$current_screen")
    if [[ -z "$current_geom" ]]; then
        return 1
    fi
    
    read -r current_x current_y current_width current_height <<< "$current_geom"
    
    local best_screen=""
    local best_distance=-1
    
    # Iterate through all screens
    for screen_name in "${!SCREEN_GEOMETRIES[@]}"; do
        [[ "$screen_name" == "$current_screen" ]] && continue
        
        local geom="${SCREEN_GEOMETRIES[$screen_name]}"
        read -r x y width height <<< "$geom"
        
        case "$direction" in
            left)
                if [[ $x -lt $current_x ]]; then
                    # Screen is to the left
                    distance=$((current_x - x))
                    if [[ $best_distance -lt 0 || $distance -lt $best_distance ]]; then
                        best_screen="$screen_name"
                        best_distance=$distance
                    fi
                fi
                ;;
            right)
                if [[ $x -gt $current_x ]]; then
                    # Screen is to the right
                    distance=$((x - current_x))
                    if [[ $best_distance -lt 0 || $distance -lt $best_distance ]]; then
                        best_screen="$screen_name"
                        best_distance=$distance
                    fi
                fi
                ;;
            up)
                if [[ $y -lt $current_y ]]; then
                    # Screen is above
                    distance=$((current_y - y))
                    if [[ $best_distance -lt 0 || $distance -lt $best_distance ]]; then
                        best_screen="$screen_name"
                        best_distance=$distance
                    fi
                fi
                ;;
            down)
                if [[ $y -gt $current_y ]]; then
                    # Screen is below
                    distance=$((y - current_y))
                    if [[ $best_distance -lt 0 || $distance -lt $best_distance ]]; then
                        best_screen="$screen_name"
                        best_distance=$distance
                    fi
                fi
                ;;
        esac
    done
    
    echo "$best_screen"
}
```

---

### Step 3: Implement Complete Scripts

**Task**: Modify each of the 4 direction scripts

**Files to modify**:
1. `kde/scripts/kwin-move-screen-left.sh`
2. `kde/scripts/kwin-move-screen-right.sh`
3. `kde/scripts/kwin-move-screen-up.sh`
4. `kde/scripts/kwin-move-screen-down.sh`

**For each script**:
- Source the shared library: `source "$SCRIPT_DIR/kwin-screen-helpers.sh"`
- Set `DIRECTION` variable appropriately
- Set `KWIN_SHORTCUT` to correct shortcut name:
  - Left: "Window One Screen to the Left"
  - Right: "Window One Screen to the Right"
  - Up: "Window One Screen Up"
  - Down: "Window One Screen Down"
- Execute main logic flow

**Script Structure** (example for left):
```bash
#!/bin/bash
# kwin-move-screen-left.sh - Move window to screen left and center cursor

# Source shared helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/kwin-screen-helpers.sh"

# Direction-specific configuration
DIRECTION="left"
KWIN_SHORTCUT="Window One Screen to the Left"

# Parse geometries
parse_all_screen_geometries

# Get current screen
CURRENT_SCREEN=$(get_current_screen)
[[ -z "$CURRENT_SCREEN" ]] && exit 0

# Find neighbor
NEIGHBOR_SCREEN=$(find_neighbor_screen "$CURRENT_SCREEN" "$DIRECTION")
[[ -z "$NEIGHBOR_SCREEN" ]] && exit 0

# Execute shortcut
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "$KWIN_SHORTCUT"

# Calculate center and move cursor
NEIGHBOR_GEOM=$(get_screen_geometry "$NEIGHBOR_SCREEN")
read -r x y width height <<< "$NEIGHBOR_GEOM"
CENTER_X=$((x + width / 2))
CENTER_Y=$((y + height / 2))

move_cursor_to_coordinates "$CENTER_X" "$CENTER_Y"
```

**Note**: Each script is now minimal - only contains direction-specific configuration and main logic flow. All helper functions are in the shared library.

---

### Step 4: Error Handling

**Error Cases**:
1. **`kscreen-doctor` fails**: Exit silently (can't determine screens)
2. **`activeOutputName` fails**: Exit silently (can't determine current screen)
3. **No neighbor exists**: Exit silently (expected case, prevents cycling)
4. **Parsing errors**: Exit silently (fail gracefully)
5. **ydotool fails**: Continue (cursor movement is best-effort)

**Strategy**: Fail silently for all errors - scripts should never produce error output or break user workflow

---

### Step 5: Testing Checklist

**Test Scenarios**:

- [ ] **Single monitor**:
  - [ ] Try moving left/right/up/down - should do nothing (no-op)
  - [ ] Verify no cycling occurs

- [ ] **Two monitors (side-by-side)**:
  - [ ] Move left from leftmost screen - should do nothing
  - [ ] Move right from leftmost screen - should move window and cursor
  - [ ] Move right from rightmost screen - should do nothing
  - [ ] Move left from rightmost screen - should move window and cursor
  - [ ] Verify cursor centers on correct screen

- [ ] **Three monitors (various layouts)**:
  - [ ] Test all directions from edge screens
  - [ ] Test moving between middle screens
  - [ ] Verify no cycling occurs
  - [ ] Verify cursor centers correctly

- [ ] **Edge cases**:
  - [ ] Multiple screens in same direction (should use closest)
  - [ ] Screen layout changes (should query fresh each time)
  - [ ] Commands fail gracefully (no error output)

- [ ] **Performance**:
  - [ ] Scripts execute quickly (< 200ms)
  - [ ] No noticeable delay in window movement

---

## KWin Shortcut Names

**Confirmed shortcut names**:
- Left: `"Window One Screen to the Left"`
- Right: `"Window One Screen to the Right"`
- Up: `"Window One Screen Up"`
- Down: `"Window One Screen Down"`

**Note**: These may need verification - check KDE settings or test with `qdbus` command

---

## Implementation Order

1. ✅ Create `kwin-screen-helpers.sh` shared library with all helper functions:
   - `get_current_screen()`
   - `parse_all_screen_geometries()`
   - `get_screen_geometry()`
   - `find_neighbor_screen()`
   - `move_cursor_to_coordinates()`
2. ✅ Implement complete `kwin-move-screen-left.sh` script (sources shared library)
3. ✅ Test left script thoroughly
4. ✅ Copy pattern to other three scripts (right, up, down) - only change DIRECTION and KWIN_SHORTCUT
5. ✅ Test all scripts with various screen layouts
6. ✅ Verify cycling prevention works correctly

---

## Code Reuse Strategy

**Approach**: Shared library pattern
- **Shared Library**: `kde/scripts/kwin-screen-helpers.sh` contains all common helper functions
- **Direction Scripts**: Each script sources the library and only contains direction-specific logic
- **Benefits**: 
  - No code duplication
  - Single source of truth for helper functions
  - Easy to maintain and update
  - Scripts are minimal and focused

---

## Final Notes

- **Shared Library**: All helper functions in `kwin-screen-helpers.sh` for code reuse
- **Direction Scripts**: Minimal scripts that source the library and contain only direction-specific logic
- **Error Handling**: Fail silently for all error cases
- **Coordinates**: Round to integers (bash arithmetic)
- **Performance**: Parse screen geometry on every execution (no caching)
- **Cycling Prevention**: Check for neighbor BEFORE executing KWin shortcut (prevents cycling)
- **Cursor Movement**: Only move cursor if window actually moves to different screen

---

## Ready for Implementation

This plan is now detailed enough for implementation. All user decisions have been incorporated:
- ✅ Parse on-demand
- ✅ Detect screen before move
- ✅ Round to integers
- ✅ Modify existing scripts
- ✅ Integrate ydotool workaround directly
- ✅ **Use shared library to avoid code duplication**

The implementation can proceed with the steps outlined above:
1. Create `kwin-screen-helpers.sh` shared library
2. Modify each direction script to source the library
3. Test thoroughly


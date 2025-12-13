# Concepts: Solving ydotool Coordinate Scaling Issue

## Problem Summary

ydotool's relative movement uses exactly **0.5x scaling** compared to KWin's global coordinate system. When scripts calculate target coordinates (e.g., 960, 540) and pass them to ydotool, the cursor ends up at half the intended position (480, 270).

**Current State**: 
- Workaround exists (move to 0,0 then relative movement)
- Scaling factor identified as exactly 0.5x
- Root cause unknown (may be uinput device resolution, Wayland compositor behavior, or system-level property)

## Solution Concepts

### Concept 1: Dynamic Detection with Caching (Recommended ⭐)

**Approach**: Automatically detect the scaling factor by testing actual cursor movement, cache the result, and apply it to all coordinate calculations.

**How it works**:
1. **Detection Phase**:
   - Save current cursor position
   - Move cursor to (0,0) using absolute coordinates
   - Move relatively by a known test distance (e.g., 100, 100)
   - Query actual cursor position using `xdotool getmouselocation` (works via Xwayland)
   - Calculate scaling factor: `actual_movement / expected_movement`
   - Restore original cursor position

2. **Caching**:
   - Store detected factor in `~/.config/ydotool-scaling.conf`
   - Include timestamp and system info (resolution, compositor, etc.)
   - Re-detect if system configuration changes

3. **Application**:
   - Load cached factor or detect on first use
   - Apply scaling: `adjusted_coords = target_coords / scaling_factor`
   - Use adjusted coordinates in ydotool relative movement

**Pros**:
- ✅ Works automatically on any system
- ✅ Handles different scaling factors (not just 0.5x)
- ✅ Portable across different hardware/configurations
- ✅ Self-healing if system configuration changes
- ✅ Can include manual override option

**Cons**:
- ❌ Requires cursor position query capability (xdotool via Xwayland)
- ❌ Slightly more complex implementation
- ❌ Small performance overhead on first run
- ❌ May fail if xdotool unavailable (unlikely in KDE/Wayland)

**Complexity**: Medium  
**Portability**: Excellent  
**Reliability**: High

---

### Concept 2: Hardcoded 0.5x Scaling (Simplest)

**Approach**: Simply divide all coordinates by 2 before passing to ydotool, hardcoding the 0.5x scaling factor.

**How it works**:
- Modify `move_cursor_to_coordinates()` to divide `target_x` and `target_y` by 2
- Use bash integer division: `$((target_x / 2))`
- Add comment explaining why division is necessary

**Pros**:
- ✅ Extremely simple implementation (one-line change)
- ✅ No dependencies beyond existing code
- ✅ Fast execution (no detection overhead)
- ✅ Works immediately for current system

**Cons**:
- ❌ Not portable - assumes 0.5x scaling on all systems
- ❌ Will break on systems with different scaling factors
- ❌ No way to adapt if scaling changes
- ❌ Doesn't address root cause understanding

**Complexity**: Very Low  
**Portability**: Poor  
**Reliability**: High (for current system only)

---

### Concept 3: System Property Detection

**Approach**: Try to infer scaling factor from system properties (display resolution, native resolution, compositor settings).

**How it works**:
1. Query system properties:
   - Compare native resolution vs current resolution (e.g., 3072×1920 vs 1920×1200)
   - Check KDE display scaling settings (`kscreen-doctor -o`)
   - Query compositor for coordinate system properties
   - Check uinput device properties (if available)

2. Calculate scaling factor from properties:
   - Example: If native is 2x current resolution, scaling might be 0.5x
   - Use heuristics to map system properties to scaling factor

3. Apply calculated scaling factor

**Pros**:
- ✅ No cursor movement required (non-intrusive)
- ✅ Fast detection (no delays)
- ✅ Could provide insights into root cause

**Cons**:
- ❌ Unreliable - correlation between properties and scaling may not exist
- ❌ Complex heuristics needed
- ❌ May not work across different systems/compositors
- ❌ Requires extensive testing to validate correlations

**Complexity**: High  
**Portability**: Medium  
**Reliability**: Low-Medium

---

### Concept 4: Hybrid Approach (Detection + Fallbacks)

**Approach**: Combine dynamic detection with system property detection and manual override, using fallbacks if primary method fails.

**How it works**:
1. **Primary**: Dynamic detection via cursor movement test
2. **Fallback 1**: System property detection (if dynamic fails)
3. **Fallback 2**: Default to 0.5x (if both fail)
4. **Override**: Allow manual configuration in config file

**Pros**:
- ✅ Most robust - multiple detection methods
- ✅ Handles edge cases where one method fails
- ✅ Provides flexibility for users
- ✅ Can learn from system properties over time

**Cons**:
- ❌ Most complex implementation
- ❌ Requires maintaining multiple detection methods
- ❌ More code to test and maintain
- ❌ May be overkill if dynamic detection works reliably

**Complexity**: High  
**Portability**: Excellent  
**Reliability**: Very High

---

### Concept 5: Manual Configuration Only

**Approach**: Require users to manually configure the scaling factor in a config file, no automatic detection.

**How it works**:
- Create config file `~/.config/ydotool-scaling.conf` with `factor=0.5`
- Script reads factor from config file
- User must set correct value for their system
- Provide documentation/instructions for determining factor

**Pros**:
- ✅ Simplest implementation (no detection logic)
- ✅ User has full control
- ✅ No dependencies on cursor query tools
- ✅ Fast execution

**Cons**:
- ❌ Requires manual setup on each system
- ❌ User must know how to determine scaling factor
- ❌ Not user-friendly
- ❌ Easy to misconfigure

**Complexity**: Low  
**Portability**: Medium (requires manual config)  
**Reliability**: Medium (depends on user accuracy)

---

## Recommendation

**Recommended: Concept 1 (Dynamic Detection with Caching)**

This provides the best balance of:
- **Automatic operation** - works out of the box
- **Portability** - adapts to different systems
- **Reliability** - tested against actual cursor movement
- **Simplicity** - straightforward implementation

**Fallback Strategy**: If dynamic detection proves unreliable, fall back to Concept 2 (hardcoded 0.5x) for immediate fix, then investigate Concept 3 (system properties) to understand root cause.

---

## Key Questions for Decision

1. **Portability Priority**: How important is it that these scripts work on other computers/configurations? 
   - If high → Concept 1 or 4
   - If low → Concept 2

2. **Detection Reliability**: Are you comfortable relying on `xdotool getmouselocation` for detection?
   - If yes → Concept 1
   - If no → Concept 2 or 5

3. **Root Cause Understanding**: Do you want to continue investigating what causes the scaling?
   - If yes → Concept 1 or 3 (detection may reveal patterns)
   - If no → Concept 2 (quick fix)

4. **Complexity Tolerance**: How much complexity are you willing to accept?
   - Low → Concept 2 or 5
   - Medium → Concept 1
   - High → Concept 4

---

## Implementation Notes

### For Concept 1 (Dynamic Detection):

**Detection Function Requirements**:
- Must be non-destructive (restore cursor position)
- Should complete quickly (< 1 second)
- Must handle errors gracefully
- Should cache result to avoid repeated detection

**Config File Format**:
```ini
[ydotool_scaling]
factor=0.5
detected_at=2025-12-13T01:00:00Z
detection_method=dynamic
system_info=wayland:kwin:native_res=3072x1920:current_res=1920x1200
```

**Integration Points**:
- Modify `move_cursor_to_coordinates()` in `kwin-screen-helpers.sh`
- Add `detect_ydotool_scaling()` function
- Add `get_ydotool_scaling_factor()` function
- Create config file management functions

### For Concept 2 (Hardcoded):

**Implementation**:
```bash
move_cursor_to_coordinates() {
    local target_x=$1
    local target_y=$2
    
    export YDOTOOL_SOCKET=/tmp/.ydotool_socket
    
    # Apply 0.5x scaling: divide coordinates by 2
    # ydotool relative movement uses 0.5x scaling compared to KWin coordinates
    local adjusted_x=$((target_x / 2))
    local adjusted_y=$((target_y / 2))
    
    # Step 1: Move to origin (0,0) using absolute
    ydotool mousemove --absolute -x 0 -y 0 2>/dev/null
    sleep 0.05
    
    # Step 2: Move relatively with adjusted coordinates
    ydotool mousemove -x "$adjusted_x" -y "$adjusted_y" 2>/dev/null
}
```

---

## Next Steps

1. **Choose a concept** based on your priorities (portability, complexity, etc.)
2. **Validate assumptions** (e.g., test if xdotool works for cursor position queries)
3. **Create detailed plan** using `/plan` command
4. **Implement and test** the chosen solution


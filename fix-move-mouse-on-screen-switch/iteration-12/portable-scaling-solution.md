# Portable Scaling Solution: Dynamic Detection and Configuration

## Problem Statement

The ydotool coordinate scaling issue (0.5x) needs to be handled portably across different computer configurations. We cannot hardcode a 0.5x scaling factor because:

1. **Different systems may have different scaling factors**
2. **Display configurations vary** (different resolutions, scaling settings)
3. **uinput device behavior may differ** across systems
4. **Wayland compositor implementations vary** (KWin, GNOME, Sway, etc.)

## Solution Approach

### Strategy 1: Dynamic Detection (Recommended)

**Detect scaling factor by testing actual cursor movement:**

1. **Calibration Test**:
   - Move cursor to known position (0,0) using absolute coordinates
   - Move relatively by known amount (e.g., 100, 100)
   - Query actual cursor position
   - Calculate scaling factor: `actual_movement / expected_movement`

2. **Cache Result**:
   - Store detected scaling factor in config file
   - Re-detect if system configuration changes
   - Allow manual override if detection fails

3. **Apply Scaling**:
   - Multiply target coordinates by inverse of scaling factor
   - Example: If scaling is 0.5x, multiply by 2.0

### Strategy 2: System Property Detection

**Query system properties that might indicate scaling:**

1. **Display Scaling Settings**:
   - KDE: `kscreen-doctor -o` shows Scale values
   - Wayland: Check `WAYLAND_DISPLAY` and compositor-specific settings
   - X11: Check `xrandr --query` for scaling

2. **Native vs Current Resolution**:
   - Compare native resolution to current resolution
   - Calculate hardware scaling factor
   - May correlate with uinput device resolution

3. **Compositor Information**:
   - Query compositor for coordinate system properties
   - Check if compositor reports scaling factors

### Strategy 3: Hybrid Approach (Best for Portability)

**Combine detection methods with fallbacks:**

1. **Primary**: Dynamic detection via cursor movement test
2. **Fallback**: System property detection
3. **Manual Override**: User-configurable scaling factor

## Implementation Plan

### Phase 1: Detection Function

Create `detect_ydotool_scaling()` function that:

```bash
detect_ydotool_scaling() {
    # 1. Move to (0,0) using absolute
    # 2. Move relatively by test amount (e.g., 100, 100)
    # 3. Query actual position
    # 4. Calculate scaling factor
    # 5. Return scaling factor or error
}
```

### Phase 2: Configuration Storage

Create config file (e.g., `~/.config/ydotool-scaling.conf`) that stores:

```ini
[scaling]
factor=0.5
detected_at=2025-12-13T01:00:00
detection_method=dynamic
system_info=...
```

### Phase 3: Integration

Modify `move_cursor_to_coordinates()` to:

1. Check for cached scaling factor
2. If not found or expired, detect scaling factor
3. Apply scaling: `target_coords = target_coords / scaling_factor`
4. Execute ydotool movement

## Key Questions to Answer

### Q1: What Determines the Scaling Factor?

**Hypotheses to Test**:
- uinput device implicit resolution (based on highest native resolution?)
- Wayland compositor coordinate transformation
- Display scaling settings
- Hardware scaling (native vs current resolution)

**Investigation Needed**:
- Test on systems with different display configurations
- Compare scaling factors across different systems
- Check if scaling correlates with any system properties

### Q2: Is Scaling Factor Consistent?

**Questions**:
- Does scaling factor change with display resolution changes?
- Is it consistent across different screens in multi-monitor setup?
- Does it vary with Wayland compositor (KWin vs GNOME vs Sway)?

**Testing Needed**:
- Change display resolution and re-test scaling
- Test on different Wayland compositors
- Test on different hardware configurations

### Q3: Can We Query Scaling Factor?

**Possible Methods**:
- Query uinput device properties (if available)
- Query Wayland compositor for coordinate system info
- Query libinput for device resolution
- Test actual movement (most reliable)

## Detection Script Design

### Requirements

1. **Non-destructive**: Should not interfere with user's current cursor position
2. **Fast**: Should complete quickly (< 1 second)
3. **Reliable**: Should work consistently across different systems
4. **Configurable**: Should allow manual override

### Implementation

```bash
detect_ydotool_scaling() {
    local test_distance=100
    local cache_file="$HOME/.config/ydotool-scaling.conf"
    
    # Save current cursor position
    local start_pos=$(xdotool getmouselocation 2>/dev/null)
    local start_x=$(echo "$start_pos" | grep -oP 'x:\K\d+')
    local start_y=$(echo "$start_pos" | grep -oP 'y:\K\d+')
    
    # Move to (0,0) then test relative movement
    ydotool mousemove --absolute -x 0 -y 0 2>/dev/null
    sleep 0.1
    ydotool mousemove -x $test_distance -y $test_distance 2>/dev/null
    sleep 0.5
    
    # Query actual position
    local end_pos=$(xdotool getmouselocation 2>/dev/null)
    local end_x=$(echo "$end_pos" | grep -oP 'x:\K\d+')
    local end_y=$(echo "$end_pos" | grep -oP 'y:\K\d+')
    
    # Calculate scaling factor
    local actual_x=$((end_x - 0))
    local actual_y=$((end_y - 0))
    local scale_x=$(echo "scale=3; $actual_x / $test_distance" | bc)
    local scale_y=$(echo "scale=3; $actual_y / $test_distance" | bc)
    
    # Restore cursor position
    ydotool mousemove --absolute -x $start_x -y $start_y 2>/dev/null
    
    # Return scaling factor (average of X and Y)
    echo "scale=3; ($scale_x + $scale_y) / 2" | bc
}
```

## Configuration File Format

```ini
[ydotool_scaling]
# Scaling factor detected or manually configured
# Value: 0.0 to 1.0 (e.g., 0.5 means coordinates are halved)
factor=0.5

# When was this factor detected/configured
detected_at=2025-12-13T01:00:00Z

# How was this factor determined
# Values: dynamic, manual, system_property
detection_method=dynamic

# System information at detection time
system_info=wayland:kwin:native_res=3072x1920:current_res=1920x1200

# Force re-detection if system info changes
auto_redetect=true

# Manual override (if set, use this instead of detection)
# manual_factor=
```

## Integration with kwin-screen-helpers.sh

```bash
# Load or detect scaling factor
get_ydotool_scaling_factor() {
    local cache_file="$HOME/.config/ydotool-scaling.conf"
    
    # Check cache first
    if [[ -f "$cache_file" ]]; then
        local cached_factor=$(grep "^factor=" "$cache_file" | cut -d= -f2)
        if [[ -n "$cached_factor" ]]; then
            echo "$cached_factor"
            return 0
        fi
    fi
    
    # Detect scaling factor
    local detected_factor=$(detect_ydotool_scaling)
    if [[ -n "$detected_factor" ]]; then
        # Cache the result
        mkdir -p "$(dirname "$cache_file")"
        cat > "$cache_file" <<EOF
[ydotool_scaling]
factor=$detected_factor
detected_at=$(date -Iseconds)
detection_method=dynamic
EOF
        echo "$detected_factor"
        return 0
    fi
    
    # Fallback to default (0.5)
    echo "0.5"
}

# Modified move_cursor_to_coordinates function
move_cursor_to_coordinates() {
    local target_x=$1
    local target_y=$2
    
    export YDOTOOL_SOCKET=/tmp/.ydotool_socket
    
    # Get scaling factor
    local scaling_factor=$(get_ydotool_scaling_factor)
    
    # Apply scaling: divide by scaling factor to compensate
    local adjusted_x=$(echo "scale=0; $target_x / $scaling_factor" | bc)
    local adjusted_y=$(echo "scale=0; $target_y / $scaling_factor" | bc)
    
    # Step 1: Move to origin (0,0) using absolute
    ydotool mousemove --absolute -x 0 -y 0 2>/dev/null
    sleep 0.05
    
    # Step 2: Move relatively with adjusted coordinates
    ydotool mousemove -x "$adjusted_x" -y "$adjusted_y" 2>/dev/null
}
```

## Testing Strategy

### Test Cases

1. **Different Display Configurations**:
   - Single monitor
   - Multi-monitor (different resolutions)
   - Different scaling settings

2. **Different Systems**:
   - Different hardware (laptops, desktops)
   - Different Wayland compositors (KWin, GNOME, Sway)
   - Different display resolutions

3. **Edge Cases**:
   - Very high resolution displays
   - Fractional scaling
   - Mixed DPI displays

### Validation

For each test case:
1. Detect scaling factor
2. Test cursor movement to known positions
3. Verify cursor reaches intended target
4. Document scaling factor and system properties

## Next Steps

1. **Implement detection function**: Create `detect_ydotool_scaling()` function
2. **Create configuration system**: Implement config file storage/loading
3. **Integrate with existing code**: Modify `move_cursor_to_coordinates()`
4. **Test across systems**: Validate on different computer configurations
5. **Document findings**: Record what determines scaling factor on each system

## Expected Outcomes

After implementing this solution:

1. **Portability**: Scripts work across different computer configurations
2. **Reliability**: Scaling factor detected automatically
3. **Maintainability**: Clear documentation of scaling behavior
4. **Flexibility**: Manual override available if needed

This approach ensures the dotfiles work correctly on any computer configuration while understanding what determines the scaling factor.


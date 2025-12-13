# Understanding: Portable Solution for ydotool Coordinate Scaling

## User Requirement

**Critical Requirement**: Dotfiles must work on **any computer configuration**, not just the current setup. Without understanding what determines the scaling factor, keybinds won't work reliably across different systems.

## The Portability Challenge

### Current Situation

- **Known**: ydotool uses 0.5x scaling on current system
- **Unknown**: What determines this scaling factor?
- **Risk**: Hardcoding 0.5x will fail on systems with different scaling

### Why Understanding Matters

1. **Different Systems = Different Scaling?**
   - Laptop with high-DPI display: 0.5x scaling?
   - Desktop with standard display: Different scaling?
   - Multi-monitor setup: Consistent or per-monitor?

2. **What Determines Scaling Factor?**
   - uinput device resolution (implicit or explicit)?
   - Wayland compositor behavior?
   - Display scaling settings?
   - Hardware resolution vs current resolution?

3. **Is Scaling Consistent?**
   - Same across all screens in multi-monitor setup?
   - Changes with display resolution changes?
   - Varies with Wayland compositor (KWin vs GNOME vs Sway)?

## Investigation Findings So Far

### What We Know

1. **Current System**:
   - Scaling factor: Exactly 0.5x (half scale)
   - Global effect: Affects all screens uniformly
   - Consistent: Same scaling for X and Y axes
   - uinput device: Only relative movement (ABS=0, REL=147)
   - No explicit resolution properties in sysfs

2. **Research Findings**:
   - Multiple users report similar 0.5x scaling issues
   - GitHub issue #250 documents absolute coordinate bug
   - Research suggests uinput devices can have implicit 2x resolution
   - Wayland compositors apply coordinate transformations

3. **Leading Hypothesis**:
   - uinput device created with implicit 2x resolution
   - Wayland compositor interprets relative movements at 2x resolution
   - Result: 0.5x scaling in display coordinates

### What We Don't Know (Critical for Portability)

1. **What Determines the Scaling Factor?**
   - Is it based on highest native resolution?
   - Is it based on current display resolution?
   - Is it a compositor default?
   - Is it configurable?

2. **Does Scaling Vary Across Systems?**
   - Different hardware → different scaling?
   - Different compositors → different scaling?
   - Different display configurations → different scaling?

3. **Can We Detect Scaling Dynamically?**
   - Can we query system properties?
   - Can we test actual movement?
   - Can we calculate from display properties?

## Solution Strategy: Dynamic Detection

### Approach

Instead of hardcoding 0.5x, **detect the scaling factor dynamically**:

1. **Calibration Test**:
   - Move cursor to known position (0,0)
   - Move relatively by known amount (e.g., 100 pixels)
   - Query actual cursor position
   - Calculate: `scaling_factor = actual_movement / expected_movement`

2. **Cache Result**:
   - Store detected scaling factor
   - Re-detect if system configuration changes
   - Allow manual override

3. **Apply Scaling**:
   - Use detected scaling factor
   - Compensate: `adjusted_coords = target_coords / scaling_factor`

### Benefits

- **Portable**: Works on any system regardless of scaling factor
- **Reliable**: Detects actual behavior, not assumptions
- **Maintainable**: Clear detection logic, easy to debug
- **Flexible**: Manual override available if detection fails

## Investigation Plan for Portability

### Phase 1: Understand What Determines Scaling

**Tests Needed**:

1. **Display Resolution Test**:
   - Change display resolution
   - Re-test scaling factor
   - Does scaling change with resolution?

2. **Multi-System Test**:
   - Test on different computers
   - Compare scaling factors
   - Document system properties for each

3. **Compositor Test**:
   - Test on different Wayland compositors (if available)
   - Compare scaling behavior
   - Document compositor-specific behavior

4. **System Property Correlation**:
   - Record system properties for each test
   - Look for correlations with scaling factor
   - Native resolution, current resolution, display scaling, etc.

### Phase 2: Develop Detection Method

**Implementation**:

1. **Detection Function**: Test actual cursor movement
2. **Configuration System**: Cache detected scaling factor
3. **Fallback Logic**: Default if detection fails
4. **Manual Override**: Allow user configuration

### Phase 3: Validate Across Systems

**Testing**:

1. Test on current system (known 0.5x scaling)
2. Test on different systems (if available)
3. Document scaling factors and system properties
4. Verify detection works correctly

## Key Questions to Answer

### Q1: What System Properties Correlate with Scaling?

**Hypotheses**:
- Highest native resolution across all displays?
- Current display resolution?
- Display scaling settings (KDE Scale value)?
- Wayland compositor type?
- uinput device creation parameters?

**Investigation**: Test on different systems and record properties

### Q2: Is Scaling Factor Consistent or Variable?

**Questions**:
- Same scaling across all screens?
- Changes with resolution changes?
- Varies with compositor?
- System-specific or universal?

**Investigation**: Test with different configurations

### Q3: Can We Predict Scaling from System Properties?

**Goal**: If we can predict scaling from system properties, we can:
- Detect scaling without cursor movement test
- Understand root cause better
- Document portability requirements

**Investigation**: Analyze correlations between system properties and scaling

## Implementation Priority

### Immediate (For Portability)

1. ✅ **Create detection function**: Test actual cursor movement
2. ✅ **Implement caching**: Store detected scaling factor
3. ✅ **Integrate with scripts**: Use detected scaling in `move_cursor_to_coordinates()`
4. ⏳ **Test on current system**: Validate detection works

### Short-term (For Understanding)

1. ⏳ **Test with resolution changes**: Does scaling change?
2. ⏳ **Document system properties**: Record what correlates with scaling
3. ⏳ **Test on different systems**: Compare scaling factors

### Long-term (For Complete Understanding)

1. ⏳ **Analyze correlations**: What determines scaling factor?
2. ⏳ **Document findings**: Create portability guide
3. ⏳ **Optimize detection**: Use system properties if predictable

## Expected Outcomes

### For Portability

- ✅ Scripts work on any system (detection handles differences)
- ✅ Scaling factor detected automatically
- ✅ Manual override available if needed
- ✅ Clear documentation of behavior

### For Understanding

- ✅ Know what determines scaling factor
- ✅ Understand root cause
- ✅ Document portability requirements
- ✅ Predict scaling from system properties (if possible)

## Next Steps

1. **Implement detection function** (see `portable-scaling-solution.md`)
2. **Test detection on current system**
3. **Integrate with existing scripts**
4. **Test on different systems** (when available)
5. **Document findings** for portability

This approach ensures dotfiles work correctly on any computer configuration while continuing to investigate what determines the scaling factor.


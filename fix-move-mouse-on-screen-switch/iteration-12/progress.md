# Progress: Iteration 12

## Problem Context

KDE scripts for mouse cursor movement (used with keybinds like Meta+HJKL and Meta+Shift+HJKL) no longer work after switching to Wayland. The scripts have been updated to use ydotool instead of xdotool, but there's a coordinate system mismatch where ydotool's relative movement uses exactly 0.5x scaling compared to KWin's global coordinates.

**Current Implementation**: Screen switching scripts (`kwin-move-screen-*.sh`) use a shared library pattern (`kwin-screen-helpers.sh`) with a workaround: absolute movement to (0,0) then relative movement to target coordinates. However, the relative movement uses 0.5x scaling, causing cursor to land at incorrect positions.

## Previous Iteration Summary

**Iterations 01-09**: Set up ydotool infrastructure, discovered absolute coordinate bug, found relative movement workaround, implemented shared library pattern for screen switching scripts.

**Iteration 10**: Discovered that ydotool's relative movement coordinate system uses exactly 0.5x scaling compared to KWin's global coordinates. User testing confirmed consistent 0.5x scaling across all screens and coordinates.

**Iteration 11**: Conducted systematic root cause investigation:
- Gathered system information (native resolution: 3072×1920, current: 1920×1200)
- Investigated uinput device properties (no resolution properties found)
- Researched Wayland/uinput coordinate systems
- Developed hypotheses: uinput device resolution mismatch (leading), Wayland compositor transformation, libinput coordinate mapping
- Created investigation artifacts and test scripts

## Critical Requirement: Portability

**User Requirement**: Dotfiles must work on **any computer configuration**, not just the current setup. Hardcoding 0.5x scaling will fail on systems with different scaling factors.

**Implication**: Must implement **dynamic detection** of scaling factor rather than hardcoding a fixed value.

## Completed Tasks

### Investigation Phase ✅

1. **System Analysis**:
   - ✅ Verified uinput device properties (`/dev/input/event16`): REL=147, ABS=0, no resolution properties
   - ✅ Confirmed device only supports relative movement
   - ✅ Verified display configuration: 3 monitors, native 3072×1920, current 1920×1200
   - ✅ Confirmed KWin operation mode: Xwayland (despite Wayland session)

2. **Research**:
   - ✅ Researched Wayland/uinput coordinate systems and known issues
   - ✅ Confirmed GitHub issue #250 documents the absolute coordinate bug
   - ✅ Found multiple reports of similar 0.5x scaling issues
   - ✅ Investigated libinput and Wayland compositor coordinate handling

3. **Root Cause Hypothesis Development**:
   - ✅ Identified leading hypothesis: uinput device implicit 2x resolution
   - ✅ Developed alternative hypotheses: Wayland compositor transformation, libinput mapping
   - ✅ Gathered evidence supporting hypotheses

4. **Portability Solution Design**:
   - ✅ Designed dynamic detection approach for scaling factor
   - ✅ Created detection script (`detect-scaling-factor.sh`)
   - ✅ Designed configuration system for caching detected scaling
   - ✅ Documented portable solution approach

### Documentation Created ✅

1. **investigation-findings.md**: Comprehensive findings from system analysis and research
2. **investigation-summary.md**: Summary of investigation progress and conclusions
3. **investigation-conclusion.md**: Final investigation summary with portability focus
4. **portable-scaling-solution.md**: Complete design for dynamic detection system
5. **understanding-portability.md**: Portability requirements and approach
6. **understanding-01.md**: Initial understanding document for iteration 12
7. **detect-scaling-factor.sh**: Script to detect scaling factor dynamically

## Current State

### System Configuration

- **Display Setup**: 3 monitors (DP-5, HDMI-A-1, eDP-1)
- **Laptop Screen**: Native 3072×1920, Current 1920×1200 (1.6x hardware scaling)
- **External Monitors**: Both 1920×1080, Scale: 1
- **KWin Operation Mode**: Xwayland (despite Wayland session)
- **ydotool Version**: v1.0.4 (from GitHub releases)
- **ydotoold Socket**: `/tmp/.ydotool_socket`

### uinput Device

- **Device**: `/dev/input/event16` - "ydotoold virtual device"
- **Capabilities**: REL=147 (relative movement), ABS=0 (no absolute positioning)
- **Properties**: No explicit resolution properties in sysfs
- **Key Finding**: Device only supports relative movement, confirming why workaround is necessary

### Known Behavior

- **Scaling Factor**: Exactly 0.5x (half scale) - consistent across all screens
- **Workaround**: Absolute to (0,0) then relative movement works but uses 0.5x scaling
- **Consistency**: Same scaling for X and Y axes, global effect across all screens

### Root Cause Hypothesis

**Most Likely Cause**: Combination of:
1. **uinput device implicit resolution**: Device created with implicit 2x resolution (possibly default or based on highest native resolution)
2. **Wayland compositor transformation**: KWin applies coordinate transformation when processing relative movements from uinput devices
3. **Result**: Relative movements interpreted at 2x resolution → 0.5x scaling in display coordinates

**Evidence Supporting Hypothesis**:
- ✅ Exact 0.5x scaling (suggests 2x resolution mismatch)
- ✅ Global effect across all screens (device-level property)
- ✅ Consistent behavior (compositor-level transformation)
- ✅ Research confirms uinput devices can have implicit resolution
- ✅ Known issue with ydotool on Wayland (GitHub issue #250)
- ✅ Device only supports relative movement (ABS=0, REL=147)
- ✅ Multiple users report similar issues

### Critical Unknowns (For Portability)

1. **Does scaling factor vary across systems?**
   - Different hardware → different scaling?
   - Different compositors → different scaling?
   - Different display configurations → different scaling?

2. **What determines the scaling factor?**
   - Highest native resolution?
   - Current display resolution?
   - Display scaling settings?
   - Compositor-specific behavior?

3. **Can we predict scaling from system properties?**
   - If yes: Can detect without cursor movement test
   - If no: Must use dynamic detection

## Key Decisions

### Decision 1: Focus on Portability

**Decision**: Shift focus from "fix current system" to "ensure portability across all systems"

**Rationale**: User requirement that dotfiles work on any computer configuration, not just current setup. Hardcoding 0.5x scaling would fail on systems with different scaling factors.

**Impact**: Changed solution approach from hardcoded fix to dynamic detection system.

### Decision 2: Dynamic Detection Approach

**Decision**: Implement dynamic detection of scaling factor rather than hardcoding

**Rationale**: 
- Scaling factor may vary across different systems
- Root cause not definitively confirmed
- Need portable solution that works regardless of scaling factor

**Approach**:
1. Calibration test: Move cursor to (0,0), then relatively by known amount
2. Query actual cursor position using `xdotool`
3. Calculate: `scaling_factor = actual_movement / expected_movement`
4. Cache result for future use
5. Apply scaling: `adjusted_coords = target_coords / scaling_factor`

### Decision 3: Investigation vs Implementation

**Decision**: Continue investigation while designing portable solution

**Rationale**: 
- Need to understand root cause for portability
- Can design solution that works regardless of root cause
- Investigation informs solution design

**Status**: Investigation artifacts created, portable solution designed, ready for implementation

## Current Implementation Status

### Files Modified

**None** - Investigation and design phase only. No code changes made yet.

### Files Ready for Implementation

1. **`kde/scripts/kwin-screen-helpers.sh`** (lines 186-198):
   - Current: `move_cursor_to_coordinates()` passes coordinates directly to ydotool
   - Needs: Integration of dynamic scaling detection

2. **Detection Script**: `detect-scaling-factor.sh` created and ready

### Implementation Plan

**Phase 1: Detection Function** (Ready to implement)
- Add `get_ydotool_scaling_factor()` function to `kwin-screen-helpers.sh`
- Implement caching in `~/.config/ydotool-scaling.conf`
- Use `detect-scaling-factor.sh` as reference

**Phase 2: Integration** (Ready to implement)
- Modify `move_cursor_to_coordinates()` to:
  1. Get scaling factor (cached or detected)
  2. Apply scaling: `adjusted_coords = target_coords / scaling_factor`
  3. Execute ydotool movement with adjusted coordinates

**Phase 3: Testing** (Pending)
- Test detection on current system
- Verify cursor movement accuracy
- Test on different systems (when available)

## Context for Handoff

### Critical Information

1. **Portability Requirement**: Solution must work on any computer configuration, not just current system. Cannot hardcode 0.5x scaling.

2. **Current Scaling**: Exactly 0.5x on current system, but may vary on other systems.

3. **Root Cause**: Likely uinput device implicit 2x resolution + Wayland compositor transformation, but not definitively confirmed.

4. **Solution Approach**: Dynamic detection via cursor movement test, with caching and manual override capability.

5. **Implementation Status**: Investigation complete, solution designed, ready for implementation.

### Key Files

- **Implementation Target**: `kde/scripts/kwin-screen-helpers.sh` (function `move_cursor_to_coordinates()`)
- **Detection Script**: `.thoughts/fix-move-mouse-on-screen-switch/iteration-12/detect-scaling-factor.sh`
- **Solution Design**: `.thoughts/fix-move-mouse-on-screen-switch/iteration-12/portable-scaling-solution.md`
- **Investigation**: `.thoughts/fix-move-mouse-on-screen-switch/iteration-12/investigation-findings.md`

### Next Steps

1. **Implement detection function** in `kwin-screen-helpers.sh`:
   - Add `get_ydotool_scaling_factor()` function
   - Implement config file caching (`~/.config/ydotool-scaling.conf`)
   - Reference `detect-scaling-factor.sh` for detection logic

2. **Modify `move_cursor_to_coordinates()`**:
   - Load cached scaling factor or detect if not available
   - Apply scaling: `adjusted_coords = target_coords / scaling_factor`
   - Execute ydotool movement with adjusted coordinates

3. **Test implementation**:
   - Test detection on current system
   - Verify cursor movement accuracy
   - Test all four direction scripts

4. **Continue investigation** (optional):
   - Test with different display resolutions
   - Test on different systems (when available)
   - Document what determines scaling factor

### Important Notes

- **Socket Path**: ydotool uses `/tmp/.ydotool_socket` (configured in `ydotool/ydotoold.service`)
- **Dependencies**: Requires `xdotool` for querying cursor position during detection
- **Caching**: Detected scaling factor should be cached to avoid repeated tests
- **Manual Override**: Configuration file should allow manual scaling factor override
- **Error Handling**: Detection may fail if cursor position cannot be queried - need fallback

### Investigation Artifacts Reference

All investigation findings, hypotheses, and solution design are documented in:
- `investigation-findings.md`: System analysis and research findings
- `investigation-summary.md`: Investigation progress summary
- `investigation-conclusion.md`: Final conclusions
- `portable-scaling-solution.md`: Complete solution design
- `understanding-portability.md`: Portability requirements and approach

## Summary

**Status**: Investigation complete, portable solution designed, ready for implementation

**Key Achievement**: Shifted from hardcoded fix to portable dynamic detection system

**Next Action**: Implement dynamic scaling detection in `kwin-screen-helpers.sh`

**Critical Context**: Solution must work across different computer configurations, requiring dynamic detection rather than hardcoded scaling factor.

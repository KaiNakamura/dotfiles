# Investigation Summary: Root Cause Analysis Progress

## Investigation Status

**Current Phase**: Root cause hypothesis development and validation
**Status**: Strong hypotheses developed, empirical testing needed

## Key Findings

### 1. uinput Device Properties

- **Device**: `/dev/input/event16` - "ydotoold virtual device"
- **Capabilities**: REL=147 (relative movement), ABS=0 (no absolute positioning)
- **Key Finding**: Device only supports relative movement, confirming why workaround is necessary
- **No Resolution Properties**: Device doesn't expose resolution in sysfs, suggesting implicit resolution

### 2. Research Findings

**Confirmed Issues**:
- GitHub issue #250 documents the absolute coordinate bug
- Stack Overflow discussions confirm similar coordinate scaling issues
- Multiple users report 0.5x scaling with uinput devices on Wayland

**Root Cause Theories**:
1. **uinput device implicit 2x resolution** (leading hypothesis)
2. **Wayland compositor coordinate transformation**
3. **libinput coordinate mapping**
4. **Xwayland mode coordinate handling**

### 3. System Configuration

- **Display Setup**: 3 monitors, all Scale: 1 in KDE settings
- **Laptop Screen**: Native 3072×1920, Current 1920×1200 (1.6x hardware scaling)
- **KWin Mode**: Xwayland operation mode (despite Wayland session)
- **Scaling Effect**: Global, affects all screens uniformly

## Leading Hypothesis

**uinput Device Implicit Resolution with Compositor Transformation**

The 0.5x scaling is most likely caused by:

1. **uinput device creation**: Device is created with implicit 2x resolution (possibly default or based on highest native resolution)

2. **Wayland compositor handling**: KWin applies coordinate transformation when processing relative movements from uinput devices

3. **Result**: Relative movements interpreted at 2x resolution → 0.5x scaling in display coordinates

## Evidence Summary

### Supporting Evidence

✅ Exact 0.5x scaling (suggests 2x resolution mismatch)
✅ Global effect across all screens (device-level property)
✅ Consistent behavior (compositor-level transformation)
✅ Research confirms uinput devices can have implicit resolution
✅ Known issue with ydotool on Wayland (GitHub issue #250)
✅ Device only supports relative movement (ABS=0, REL=147)
✅ Multiple users report similar issues

### Unanswered Questions

❓ Does scaling apply to ALL relative movements or only with workaround?
❓ Is scaling consistent from different starting positions?
❓ Can we query/configure uinput device resolution?
❓ Does changing display resolution affect scaling factor?

## Next Steps

### Immediate Actions

1. **Execute Test Script**: Run `investigation-test.sh` to gather empirical data
2. **Examine Source Code**: Review ydotool GitHub repository for uinput device creation
3. **Test Resolution Changes**: Change display resolution and verify scaling behavior

### Research Actions

4. **Check KWin Source**: Investigate how KWin handles uinput devices
5. **Research libinput**: Understand libinput coordinate mapping
6. **Query Cursor Position**: Use xdotool to verify actual cursor positions during tests

## Test Script Status

**Created**: `investigation-test.sh` in iteration 11
**Location**: `.thoughts/fix-move-mouse-on-screen-switch/iteration-11/investigation-test.sh`
**Status**: Ready to execute
**Purpose**: Systematically test coordinate behavior

## Investigation Artifacts

1. **investigation-findings.md**: System information and research findings
2. **investigation-summary.md**: This document
3. **investigation-test.sh**: Test script for coordinate behavior (iteration 11)
4. **investigation-hypothesis.md**: Detailed hypothesis analysis (iteration 11)

## Conclusion

The investigation has developed **strong hypotheses** about the root cause:
- uinput device implicit 2x resolution
- Wayland compositor coordinate transformation
- Combination of both

However, **definitive confirmation** requires:
- Executing test script for empirical data
- Examining ydotool source code
- Testing with different display configurations

The investigation has provided sufficient understanding to:
1. **Implement fix** with confidence (divide by 2)
2. **Document issue** clearly for future reference
3. **Continue investigation** for deeper understanding if needed

## Recommended Approach

**Critical Requirement**: Dotfiles must work on **any computer configuration**, not just current setup. Hardcoding 0.5x scaling will fail on systems with different scaling factors.

### Solution: Dynamic Detection

**Strategy**: Detect scaling factor dynamically rather than hardcoding:

1. **Calibration Test**: Move cursor to (0,0), then relatively by known amount, query actual position
2. **Calculate Scaling**: `scaling_factor = actual_movement / expected_movement`
3. **Cache Result**: Store detected scaling factor, re-detect if system changes
4. **Apply Scaling**: Use detected factor to adjust coordinates

### Implementation Priority

**Immediate** (For Portability):
- ✅ Create detection function (see `detect-scaling-factor.sh`)
- ✅ Design portable solution (see `portable-scaling-solution.md`)
- ✅ Document portability requirements (see `understanding-portability.md`)
- ⏳ Implement detection in `kwin-screen-helpers.sh`
- ⏳ Test detection on current system

**Short-term** (For Understanding):
- ⏳ Test with resolution changes
- ⏳ Test on different systems (when available)
- ⏳ Document system properties that correlate with scaling

**Long-term** (For Complete Understanding):
- ⏳ Analyze correlations between system properties and scaling
- ⏳ Document findings for portability guide
- ⏳ Optimize detection using system properties if predictable

### Investigation Artifacts Created

1. **investigation-findings.md**: System information and research findings
2. **investigation-summary.md**: This document
3. **portable-scaling-solution.md**: Design for dynamic detection system
4. **understanding-portability.md**: Portability requirements and approach
5. **detect-scaling-factor.sh**: Script to detect scaling factor dynamically

The investigation has shifted focus to **portability** - ensuring the solution works across different computer configurations by detecting scaling dynamically rather than assuming a fixed value.


# Plan: Verify KWin Scripting Viability for Cursor Movement

## Objective

Verify that KWin scripting can be used to move the mouse cursor to specific locations on screens via terminal commands. This is a **verification-only** plan - we will not integrate into dotfiles yet, just test if the solution is viable.

## Context

**Problem**: `kwin-center-cursor.sh` uses `xdotool` which doesn't work on Wayland. `ydotool` was attempted but has a coordinate bug that makes it unusable.

**Proposed Solution**: Use KWin's native JavaScript scripting API to control cursor position directly within the compositor, avoiding Wayland security restrictions.

**Key Unknown**: Whether KWin scripting API actually supports cursor movement (`workspace.cursorPos` assignment or equivalent).

## Verification Goals

1. ✅ **Confirm cursor movement API exists**: Verify we can set cursor position using KWin scripting
2. ✅ **Test absolute coordinates**: Verify cursor moves to exact screen coordinates (not relative)
3. ✅ **Test multi-screen support**: Verify cursor can be moved to specific coordinates on different screens
4. ✅ **Test window geometry access**: Verify we can get active window position and size
5. ✅ **Test script invocation**: Verify scripts can be invoked from terminal (via D-Bus or console)
6. ✅ **Document limitations**: Identify any restrictions or issues encountered

## Research Findings

Based on initial research:
- KWin scripting console can be accessed via `plasma-interactiveconsole --kwin` or KRunner (`Alt+F2` → `wm console`)
- `workspace.cursorPos` property exists and can be set using `Qt.point(x, y)`
- Scripts can be loaded via D-Bus: `qdbus org.kde.KWin /Scripting loadScript /path/to/script.js`
- Scripts run within compositor, avoiding Wayland security restrictions

**Note**: Need to verify these findings work in practice.

## Verification Steps

### Step 1: Access KWin Scripting Console

**Goal**: Verify we can interact with KWin scripting API from terminal.

**Commands to test**:
```bash
# Method 1: Open interactive console
plasma-interactiveconsole --kwin

# Method 2: Via KRunner (manual - Alt+F2, type "wm console")
# Method 3: Via D-Bus (for Plasma < 5.23)
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.showInteractiveKWinConsole
```

**Expected Result**: Console opens and allows JavaScript execution.

**Success Criteria**: Console opens successfully, can execute basic JavaScript.

---

### Step 2: Test Basic Cursor Movement

**Goal**: Verify we can move cursor to a specific coordinate using KWin scripting.

**Test Script** (`test-cursor-move.js`):
```javascript
// Test moving cursor to coordinates (500, 300)
workspace.cursorPos = Qt.point(500, 300);
print("Cursor moved to (500, 300)");
```

**Commands to test**:
```bash
# Create test script
cat > /tmp/test-cursor-move.js << 'EOF'
workspace.cursorPos = Qt.point(500, 300);
print("Cursor moved to (500, 300)");
EOF

# Method 1: Execute in interactive console
# (Open console, paste script, execute)

# Method 2: Load via D-Bus
qdbus org.kde.KWin /Scripting loadScript /tmp/test-cursor-move.js
```

**Expected Result**: Cursor moves to coordinates (500, 300).

**Success Criteria**: 
- Script executes without errors
- Cursor actually moves to specified coordinates
- Coordinates are absolute (not relative to current position)

**What to verify**:
- Does `workspace.cursorPos = Qt.point(x, y)` work?
- Are coordinates absolute or relative?
- Are coordinates screen-relative or global?

---

### Step 3: Test Multi-Screen Coordinates

**Goal**: Verify cursor can be moved to specific coordinates on different screens.

**Test Script** (`test-multi-screen.js`):
```javascript
// Test moving cursor to different screen locations
// Assuming two screens: primary at (0,0) and secondary at (1920,0)
workspace.cursorPos = Qt.point(100, 100);      // Primary screen
print("Moved to primary screen (100, 100)");

// Wait a moment, then move to secondary screen
callLater(function() {
    workspace.cursorPos = Qt.point(2000, 100);  // Secondary screen
    print("Moved to secondary screen (2000, 100)");
}, 1000);
```

**Commands to test**:
```bash
# Create test script
cat > /tmp/test-multi-screen.js << 'EOF'
workspace.cursorPos = Qt.point(100, 100);
print("Moved to primary screen (100, 100)");
callLater(function() {
    workspace.cursorPos = Qt.point(2000, 100);
    print("Moved to secondary screen (2000, 100)");
}, 1000);
EOF

# Execute via console or D-Bus
```

**Expected Result**: Cursor moves to both screen locations correctly.

**Success Criteria**:
- Cursor moves to correct coordinates on primary screen
- Cursor moves to correct coordinates on secondary screen
- Coordinates work across screen boundaries

**What to verify**:
- How are multi-screen coordinates handled?
- Are coordinates global (across all screens) or per-screen?
- How to determine screen boundaries/offsets?

---

### Step 4: Test Window Geometry Access

**Goal**: Verify we can get active window position and size using KWin scripting.

**Test Script** (`test-window-geometry.js`):
```javascript
// Get active window geometry
var client = workspace.activeClient;
if (client) {
    print("Active window:");
    print("  X: " + client.x);
    print("  Y: " + client.y);
    print("  Width: " + client.width);
    print("  Height: " + client.height);
    
    // Calculate center
    var centerX = client.x + client.width / 2;
    var centerY = client.y + client.height / 2;
    print("  Center: (" + centerX + ", " + centerY + ")");
    
    // Move cursor to center
    workspace.cursorPos = Qt.point(centerX, centerY);
    print("Cursor moved to window center");
} else {
    print("No active window");
}
```

**Commands to test**:
```bash
# Create test script
cat > /tmp/test-window-geometry.js << 'EOF'
var client = workspace.activeClient;
if (client) {
    print("Active window:");
    print("  X: " + client.x);
    print("  Y: " + client.y);
    print("  Width: " + client.width);
    print("  Height: " + client.height);
    
    var centerX = client.x + client.width / 2;
    var centerY = client.y + client.height / 2;
    print("  Center: (" + centerX + ", " + centerY + ")");
    
    workspace.cursorPos = Qt.point(centerX, centerY);
    print("Cursor moved to window center");
} else {
    print("No active window");
}
EOF

# Execute via console or D-Bus
```

**Expected Result**: Script outputs window geometry and moves cursor to window center.

**Success Criteria**:
- Can access `workspace.activeClient`
- Can read `client.x`, `client.y`, `client.width`, `client.height`
- Coordinates are correct and cursor moves to calculated center

**What to verify**:
- What properties are available on `client` object?
- Are coordinates screen-relative or global?
- Does `activeClient` update immediately after window switch?

---

### Step 5: Test Script Invocation from Terminal

**Goal**: Verify scripts can be invoked from terminal commands (for integration with shell scripts).

**Test Approaches**:

**Approach A: D-Bus Script Loading**
```bash
# Load script
qdbus org.kde.KWin /Scripting loadScript /tmp/test-cursor-move.js

# Execute script (if supported)
qdbus org.kde.KWin /Scripting/Script0 run
```

**Approach B: Standalone Script File**
```bash
# Create script that can be executed
cat > /tmp/kwin-move-cursor.js << 'EOF'
workspace.cursorPos = Qt.point(500, 300);
EOF

# Execute via D-Bus
qdbus org.kde.KWin /Scripting loadScript /tmp/kwin-move-cursor.js
```

**Approach C: Shell Wrapper Script**
```bash
# Create wrapper that loads and executes
cat > /tmp/test-kwin-cursor.sh << 'EOF'
#!/bin/bash
SCRIPT_PATH="/tmp/kwin-move-cursor.js"
qdbus org.kde.KWin /Scripting loadScript "$SCRIPT_PATH"
EOF
chmod +x /tmp/test-kwin-cursor.sh
/tmp/test-kwin-cursor.sh
```

**Expected Result**: Script can be invoked from terminal and cursor moves.

**Success Criteria**:
- Script can be loaded via D-Bus from terminal
- Script executes and cursor moves
- Process is reliable and repeatable

**What to verify**:
- Can scripts be executed on-demand (not just loaded)?
- What is the D-Bus interface for script execution?
- Can we pass parameters to scripts?
- Is there a better way to invoke scripts from shell?

---

### Step 6: Test Integration Pattern (Simulated)

**Goal**: Simulate how the script would be called from existing shell scripts.

**Test**: Create a minimal version of what `kwin-center-cursor.sh` would become:

**New Script** (`test-kwin-center-cursor.sh`):
```bash
#!/bin/bash
# Simulated version using KWin scripting

# Wait a moment for focus/position to settle
sleep 0.01

# Create temporary KWin script
SCRIPT_FILE=$(mktemp)
cat > "$SCRIPT_FILE" << 'EOF'
var client = workspace.activeClient;
if (client) {
    var centerX = client.x + client.width / 2;
    var centerY = client.y + client.height / 2;
    workspace.cursorPos = Qt.point(centerX, centerY);
}
EOF

# Execute via D-Bus
qdbus org.kde.KWin /Scripting loadScript "$SCRIPT_FILE"

# Cleanup
rm "$SCRIPT_FILE"
```

**Commands to test**:
```bash
chmod +x /tmp/test-kwin-center-cursor.sh
/tmp/test-kwin-center-cursor.sh
```

**Expected Result**: Script centers cursor on active window, similar to original `kwin-center-cursor.sh`.

**Success Criteria**:
- Script works when called from terminal
- Cursor centers correctly on active window
- Timing is acceptable (no noticeable delay)

**What to verify**:
- Is this approach reliable?
- Are there performance concerns?
- Can we optimize script loading/reuse?

---

## Verification Checklist

- [ ] **Step 1**: KWin scripting console accessible from terminal
- [ ] **Step 2**: Basic cursor movement works (`workspace.cursorPos = Qt.point(x, y)`)
- [ ] **Step 2**: Coordinates are absolute (not relative)
- [ ] **Step 3**: Multi-screen coordinates work correctly
- [ ] **Step 4**: Window geometry accessible (`workspace.activeClient.x/y/width/height`)
- [ ] **Step 4**: Can calculate and move to window center
- [ ] **Step 5**: Scripts can be invoked from terminal via D-Bus
- [ ] **Step 6**: Simulated integration pattern works reliably

## Success Criteria for Viability

**KWin scripting is VIABLE if**:
1. ✅ Cursor movement API works (`workspace.cursorPos` assignment)
2. ✅ Absolute coordinates work correctly
3. ✅ Multi-screen coordinates work correctly
4. ✅ Window geometry is accessible
5. ✅ Scripts can be invoked from terminal
6. ✅ Performance is acceptable (< 100ms delay)

**KWin scripting is NOT VIABLE if**:
1. ❌ Cursor movement API doesn't exist or doesn't work
2. ❌ Coordinates are relative instead of absolute
3. ❌ Multi-screen coordinates don't work
4. ❌ Window geometry is not accessible
5. ❌ Scripts cannot be invoked from terminal
6. ❌ Performance is unacceptable (> 500ms delay)

## Documentation Requirements

For each step, document:
- **Command used**: Exact terminal commands executed
- **Result**: What happened (success/failure/errors)
- **Observations**: Any unexpected behavior or limitations
- **Screenshots/Output**: Capture console output or script results
- **API Details**: Document exact API methods/properties used

## Next Steps After Verification

**If VIABLE**:
- Proceed to full integration plan
- Design script installation process
- Plan integration with existing shell scripts
- Update `kde/apply-scripts.sh` installation script

**If NOT VIABLE**:
- Document why it doesn't work
- Explore alternative solutions (KWin D-Bus interface, libei, etc.)
- Consider fallback options

## Questions to Answer During Verification

1. **API Questions**:
   - What is the exact API for setting cursor position?
   - Are coordinates global (across all screens) or per-screen?
   - How to determine screen boundaries/offsets?

2. **Script Execution Questions**:
   - Can scripts be executed on-demand, or only loaded?
   - What is the D-Bus interface for script execution?
   - Can we pass parameters to scripts?
   - Is there a better way to invoke scripts from shell?

3. **Performance Questions**:
   - How fast is script loading/execution?
   - Is there a way to reuse loaded scripts?
   - Are there any performance concerns?

4. **Integration Questions**:
   - Can we create a reusable script that gets loaded once?
   - Or do we need to create/load script each time?
   - What is the best pattern for shell script integration?

## Notes

- This is a **verification-only** plan - no dotfiles integration yet
- Focus on terminal commands and testing
- Document everything for future reference
- Be prepared to pivot if KWin scripting doesn't work



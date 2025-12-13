# Iterations Summary

## Iteration 01: Initial ydotool Integration Plan

**Status**: Blocked at Phase 1.2 verification

**Approach**: Implemented Option 1 from concepts - replace `xdotool` with `ydotool` for cursor movement on Wayland, using `qdbus` to query KWin for window information.

**Progress**:
- Created implementation plan with 4 phases (Research, Setup, Script Modification, Testing)
- Started Phase 1.2: Verify ydotool Capabilities
- Confirmed `ydotool` installation and command syntax:
  - Absolute movement: `ydotool mousemove --absolute -x <x> -y <y>`
  - Relative movement: `ydotool mousemove -x <delta_x> -y <delta_y>`

**Blocker Encountered**:
- `ydotoold` daemon not running - required for `ydotool` to function
- Permission issues: `/dev/uinput` requires root or proper group membership
- User not in `input`/`uinput` groups
- Cannot test mouse movement without daemon running

**Why Reiterate**:
Phase 1.2 verification cannot be completed without resolving daemon setup and permissions. The plan assumed `ydotool` was ready to test, but daemon configuration (Phase 2.2) needs to happen before verification can proceed. Need to address daemon startup and permissions setup before continuing with verification.

**Key Learnings**:
- `ydotool` requires `ydotoold` daemon to be running
- Daemon needs access to `/dev/uinput` (typically requires root or udev rules)
- Verification phase should come after daemon setup, not before
- Need to determine daemon management approach (systemd service vs manual start)

## Iteration 02: ydotool Package Creation and Installation Integration

**Status**: Completed installation setup

**Approach**: Created a dedicated `ydotool/` package in dotfiles with installation script and systemd service file, integrated into main installation flow.

**Progress**:
- Created `ydotool/` directory structure following dotfiles package pattern
- Created `ydotool/install.sh` script that:
  - Installs ydotool via apt
  - Adds user to `input` group (with logout/login warning)
  - Copies systemd service file
  - Enables and starts `ydotoold` service
- Created `ydotool/ydotoold.service` systemd service file
- Integrated ydotool installation into main `install.sh` before KDE setup
- Installation script executed successfully

**Why Reiterate**:
Installation infrastructure is now complete. User has installed ydotool and restarted (group membership should be active). Next step is to verify that `ydotool` mouse movement commands actually work before proceeding with script modifications. Need to test functionality to ensure the setup is correct and ydotool can successfully move the mouse cursor.

**Key Learnings**:
- ydotool package structure follows existing dotfiles patterns
- Systemd service can be started automatically during installation
- User group membership requires logout/login to take effect
- Installation order matters: ydotool must be available before KDE scripts

## Iteration 03: Phase 1 Verification - ydotool Testing

**Status**: Blocked at daemon startup

**Approach**: Attempted to verify ydotool functionality and test mouse movement commands as part of Phase 1 verification.

**Progress**:
- Verified ydotool CLI tool is installed at `/usr/bin/ydotool`
- Confirmed user is in `input` group (group ID 995)
- Researched command syntax: `ydotool mousemove --absolute X Y`
- Created test script `ydotool-test.sh` for verification
- Discovered daemon service exists but is failing to start

**Blocker Encountered**:
- `ydotoold` daemon service failing with exit code 203/EXEC
- Service file references `/usr/bin/ydotoold` but executable doesn't exist
- Investigation revealed `ydotoold` is in a separate package (`ydotoold`) that wasn't installed
- Install script only installs `ydotool` package, missing the `ydotoold` daemon package
- Service cannot start because the executable it references doesn't exist

**Why Reiterate**:
The installation script is incomplete - it installs the CLI tool but not the daemon package. The systemd service file references `/usr/bin/ydotoold` which doesn't exist because the `ydotoold` package wasn't installed. Need to fix the install script to install both packages, then verify the daemon starts correctly and mouse movement works.

**Key Learnings**:
- `ydotool` and `ydotoold` are separate packages in Ubuntu/Debian repositories
- Install script needs to install both `ydotool` (CLI) and `ydotoold` (daemon) packages
- Service failure with exit code 203/EXEC indicates missing executable file
- Verification phase revealed installation script bug that needs fixing

## Iteration 04: Troubleshooting ydotoold Service Startup After Installation

**Status**: Blocked at service startup

**Approach**: Implemented Option 1 from concepts-02.md - Enhanced Systemd Service with robust restart policy. Updated service file with `Restart=always`, better dependencies, logging, and ensured uinput module loads at boot.

**Progress**:
- Updated `ydotoold.service` with enhanced configuration:
  - Changed `Restart=on-failure` to `Restart=always`
  - Added `StartLimitIntervalSec=0` to disable restart rate limiting
  - Added `After=systemd-modules-load.service` dependency
  - Changed `WantedBy=multi-user.target` to `WantedBy=graphical.target`
  - Added explicit `User=root` and `Group=input`
  - Added `StandardOutput=journal` and `StandardError=journal` for logging
- Created `uinput.conf` file to ensure uinput kernel module loads at boot
- Updated `install.sh` to copy uinput.conf to `/etc/modules-load.d/`
- User installed updated configuration and restarted system

**Blocker Encountered**:
- Service file contains unknown key: `StartLimitIntervalSec` - systemd version may not support this key
- Service status shows "inactive (dead)" - service is not starting despite being enabled
- Service is enabled but not active after reboot
- Need to investigate why service isn't starting and fix systemd compatibility issue

**Why Reiterate**:
The enhanced service configuration was implemented but the service still isn't starting. Two issues identified: (1) `StartLimitIntervalSec` key is not recognized by the systemd version, causing a configuration error, and (2) the service remains inactive after reboot despite being enabled. Need to fix the systemd compatibility issue (remove or replace unsupported key) and investigate why the service isn't starting - check logs, verify dependencies, and ensure service can start manually before troubleshooting automatic startup.

**Key Learnings**:
- `StartLimitIntervalSec` may not be available in all systemd versions (added in systemd 230)
- Service configuration errors can prevent service from loading properly
- Need to verify systemd version compatibility before using advanced service options
- Service being enabled doesn't guarantee it will start if configuration has errors

## Iteration 05: Getting ydotool-test.sh Working - Permissions and Socket Access

**Status**: Partially successful - mouse movement works but coordinates are incorrect

**Approach**: Pivoted from fixing systemd service startup to a smaller goal: getting `ydotool-test.sh` working. Focused on resolving permission issues preventing ydotool from functioning.

**Progress**:
- Created udev rule (`99-uinput.rules`) to set proper permissions on `/dev/uinput` device
- Fixed `/dev/uinput` permissions from `crw-------` to `crw-rw----` (group read/write)
- Fixed socket permissions issue: `/tmp/.ydotool_socket` was created with root-only permissions (`srw-------`)
- Updated `ydotoold.service` to automatically fix socket permissions via `ExecStartPost` and `UMask=0000`
- Fixed test script syntax: removed incorrect `--absolute` flag (ydotool uses `mousemove <x> <y>` syntax)
- Successfully got mouse movement working - `ydotool-test.sh` can move the mouse cursor

**Issue Encountered**:
- Mouse movement works but coordinates are incorrect: mouse consistently moves to top-left corner of top-leftmost monitor regardless of specified coordinates
- This is a known bug with ydotool on Wayland where absolute coordinates don't work correctly
- The "ydotoold backend unavailable" warning appears but doesn't prevent functionality

**Why Reiterate**:
While basic mouse movement is now functional, the coordinate accuracy issue prevents ydotool from being used for the actual use case (centering cursor on active window). The mouse moves to a fixed location (top-left) instead of the calculated center coordinates. Need to investigate workarounds for the coordinate issue - potentially using relative movement, finding alternative approaches, or investigating if there's a way to make absolute coordinates work correctly on Wayland.

**Key Learnings**:
- `/dev/uinput` requires udev rule with `MODE="0660"` and `GROUP="input"` for group access
- Socket `/tmp/.ydotool_socket` needs permissions `666` for user access (can be set via `ExecStartPost` in service file)
- ydotool command syntax: `ydotool mousemove <x> <y>` (no `--absolute` flag needed, coordinates are absolute by default)
- ydotool has a known bug on Wayland where absolute coordinates don't work correctly (mouse goes to top-left)
- Basic functionality works (mouse moves) but coordinate accuracy is broken

## Iteration 06: Investigating ydotool Coordinate Workarounds

**Status**: Blocked - no working workaround found

**Approach**: Focused on testing different coordinate approaches and investigating workarounds from GitHub issue #250 to get ydotool moving to correct locations on different screens.

**Progress**:
- Created comprehensive test scripts (`ydotool-coordinate-test.sh`, `ydotool-relative-test.sh`)
- Tested various coordinate values across all three monitors (DP-5, HDMI-A-1, eDP-1)
- Researched GitHub issue #250 which documents the exact same bug
- Tested workaround approaches mentioned in issue comments:
  - Moving to 0,0 first then absolute coordinates
  - Using delays between commands
  - Testing different coordinate ranges
- Verified monitor layout: 3 monitors with global coordinate system (DP-5 at 0,0; HDMI-A-1 at 1920,0; eDP-1 at 891,1080)

**Blocker Encountered**:
- All tested approaches failed - mouse consistently moves to top-left corner regardless of:
  - Coordinate values (small, large, monitor-specific)
  - Moving to 0,0 first before target coordinates
  - Adding delays between commands
  - Different coordinate ranges
- ydotool version 0.1.8-3build1 doesn't support `-x`/`-y` flags or relative movement syntax
- GitHub issue #250 is still open with no working solution
- Workarounds mentioned in issue comments don't work reliably or don't apply to this version

**Why Reiterate**:
ydotool's absolute coordinate bug appears to be a fundamental limitation that cannot be worked around with command-line options or timing tricks. The tool moves the mouse but cannot target specific coordinates on Wayland. Need to explore alternative approaches beyond ydotool - either using KWin D-Bus API directly for cursor control, custom uinput-based solutions, or KWin scripting capabilities.

**Key Learnings**:
- ydotool coordinate bug is confirmed and reproducible across all tested scenarios
- No command-line workarounds exist for the coordinate issue in version 0.1.8
- GitHub issue #250 documents this exact problem but remains unresolved
- Need to pivot to alternative solutions that don't rely on ydotool for cursor positioning
- KWin D-Bus can query window geometry but may also provide cursor control methods

## Iteration 07: KWin Scripting API Verification for Cursor Movement

**Status**: Blocked - cursor movement API doesn't work

**Approach**: Investigated KWin JavaScript scripting API as an alternative to ydotool. Attempted to verify if `workspace.cursorPos` assignment can move the cursor, testing both interactive console and D-Bus script loading methods.

**Progress**:
- Successfully accessed KWin scripting console via `plasma-interactiveconsole --kwin`
- Discovered D-Bus script loading interface: `org.kde.KWin /Scripting loadScript`
- Created multiple test scripts attempting cursor movement:
  - Direct assignment: `workspace.cursorPos = Qt.point(500, 300)`
  - Property modification: `pos.x = 500; pos.y = 300`
  - Event-driven scripts with shortcuts
- Scripts load successfully via D-Bus (return script IDs)
- Scripts execute without errors (logs show "Executing script at %1" and "Runtime: %1ms")

**Blocker Encountered**:
- **Cursor does not move** despite scripts executing successfully
- Tested in interactive console: `workspace.cursorPos = Qt.point(500, 300)` executes but cursor doesn't move
- No error messages or exceptions thrown - assignment appears to succeed silently
- Property may be read-only or API may not be functional for cursor movement in Wayland
- Multiple syntax variations tested (direct assignment, property modification, method calls) - none work

**Why Reiterate**:
KWin scripting API's `workspace.cursorPos` property appears to be read-only or non-functional for cursor movement. Scripts execute without errors but cursor doesn't move, suggesting the API either doesn't support cursor movement or has limitations in Wayland sessions. Need to explore other KWin D-Bus methods, investigate if cursor movement requires different API, or consider alternative approaches like KWin effects, D-Bus interfaces, or other Wayland-compatible solutions.

**Key Learnings**:
- KWin scripting console is accessible via `plasma-interactiveconsole --kwin`
- Scripts can be loaded via D-Bus: `qdbus org.kde.KWin /Scripting loadScript <path>`
- `workspace.cursorPos` property exists and is readable
- Assignment to `workspace.cursorPos` executes without errors but doesn't move cursor
- API may be read-only or cursor movement may require different approach/method
- Need to investigate KWin D-Bus cursor control methods or alternative APIs

## Iteration 08: ydotool v1.0.4 Upgrade and Workaround Discovery

**Status**: Partially successful - workaround found but bug persists

**Approach**: Upgraded ydotool from apt package (0.1.8) to GitHub release v1.0.4 to test if newer version fixes absolute coordinate bug. Investigated mouse acceleration settings and discovered relative movement workaround.

**Progress**:
- Updated `ydotool/install.sh` to download v1.0.4 binaries from GitHub releases
- Upgraded both `ydotool` and `ydotoold` to v1.0.4
- Updated `ydotoold.service` to use new daemon with `--socket-path` option
- Configured `YDOTOOL_SOCKET` environment variable for v1.0.4 compatibility
- Disabled mouse acceleration (`XLbInptPointerAcceleration=0`) as recommended by ydotool help
- Created `disable-mouse-accel.sh` script for acceleration management
- Tested absolute coordinates with v1.0.4 - bug still present
- Discovered workaround: move to (0,0) with absolute, then use relative movement to target

**Findings**:
- **Bug persists in v1.0.4**: Absolute coordinates still move cursor to top-left corner (0,0)
- **Arguments parsed correctly**: Debug output confirms `--absolute -x 100 -y 100` is parsed properly
- **Mouse acceleration disabled**: Set to 0, but bug remains - acceleration is not the root cause
- **Workaround works**: Two-step process (absolute to 0,0 then relative to target) successfully positions cursor
- **Workaround limitation**: Brief visual flash to top-left corner before correcting to target position

**Why Reiterate**:
While a workaround exists, it has a visual artifact (brief flash to top-left). Need to implement the workaround in `kwin-center-cursor.sh` script and test if it's acceptable for the use case. Also need to update scripts to use new v1.0.4 syntax (`--absolute -x -y` flags) and handle the two-step movement process.

**Key Learnings**:
- ydotool v1.0.4 syntax: `ydotool mousemove --absolute -x <x> -y <y>` (different from 0.1.8)
- v1.0.4 uses different socket path by default (`/run/user/UID/.ydotool_socket`) but can be configured
- Bug is in daemon's coordinate handling, not argument parsing or acceleration
- Relative movement (`-x`, `-y` without `--absolute`) works correctly
- Workaround: absolute to (0,0) then relative to target achieves correct positioning
- Workaround is acceptable tradeoff for use case (brief flash is tolerable)

## Iteration 09: Screen Switching Scripts Implementation with Shared Library Pattern

**Status**: Partially successful - implementation complete but coordinate calculation issue discovered

**Approach**: Implemented Concept 2 from plan-02.md - shared library pattern for screen switching scripts. Created `kwin-screen-helpers.sh` with helper functions and modified all 4 direction scripts to prevent cycling and center cursor on target screen.

**Progress**:
- Created `kde/scripts/kwin-screen-helpers.sh` shared library with helper functions:
  - `get_current_screen()` - Gets current active screen via qdbus
  - `parse_all_screen_geometries()` - Parses kscreen-doctor output (fixed ANSI color code issue)
  - `get_screen_geometry()` - Retrieves geometry for specific screen
  - `find_neighbor_screen()` - Finds closest neighbor with overlap prioritization
  - `move_cursor_to_coordinates()` - Moves cursor using ydotool workaround
- Modified all 4 direction scripts (`kwin-move-screen-*.sh`) to use shared library
- Fixed neighbor detection to prioritize screens with vertical/horizontal overlap
- Fixed Wayland shortcut reload issue in `apply-scripts.sh` (uses D-Bus reconfigure instead of service restart)
- Fixed ANSI color code parsing in kscreen-doctor output (strips escape sequences)

**Issue Discovered**:
- **Large relative movements fail**: When moving relatively by (960, 540) from (0,0), cursor ends up at center of all 3 screens (1897, 920) instead of target
- **Small movements work**: Relative movements like (10, 10) or (100, 100) work correctly
- **Specific coordinate works**: User discovered `ydotool mousemove --absolute -x 0 -y 0 && ydotool mousemove -x 475 -y 275` correctly centers on leftmost screen
- **Root cause unknown**: Need to understand why relative movement behaves differently for large vs small values

**Why Reiterate**:
The implementation is complete and scripts execute correctly, but the cursor movement doesn't reach the intended target coordinates. Large relative movements (like 960, 540) end up at an unexpected location (center of all screens), while smaller movements work correctly. The user discovered that (475, 275) works correctly, suggesting there may be a coordinate system issue, scaling problem, or threshold in ydotool's relative movement handling. Need to investigate the coordinate system behavior and understand why large relative movements fail before implementing a robust solution.

**Key Learnings**:
- Shared library pattern successfully eliminates code duplication
- Neighbor detection with overlap prioritization correctly identifies adjacent screens
- ANSI color codes in kscreen-doctor output must be stripped before parsing
- Wayland requires D-Bus reconfigure method for shortcut reload (service restart fails)
- ydotool relative movement appears to have issues with large coordinate values
- Need to understand coordinate system and relative movement behavior before implementing fix

## Iteration 10: Understanding Coordinate System Mismatch

**Status**: Understanding complete - root cause investigation needed

**Approach**: Investigated the coordinate accuracy issue discovered in iteration 09. User testing revealed that ydotool's relative movement coordinate system uses exactly 0.5x scaling compared to KWin's global coordinates.

**Progress**:
- Discovered that ALL coordinates are wrong, not just large ones - systematic coordinate system mismatch
- User testing confirmed exact 0.5x scaling factor:
  - Left monitor center: (960, 540) requires (480, 270) → 0.5x
  - Right monitor center: (2880, 540) requires (1440, 270) → 0.5x
  - Top edge between monitors: (1920, 0) requires (960, 0) → 0.5x
  - Bottom monitor center: ~(1851, 1680) requires (960, 810) → ~0.5x
- Created understanding documents analyzing the coordinate system mismatch
- Identified that simple division by 2 would fix the issue, but root cause unknown

**Why Reiterate**:
While the scaling factor is known (0.5x), the root cause is not understood. User identified a potential clue: laptop screen is 3840×2400 native resolution but set to 1920×1200 (2x scaling). NOTE: This was actually incorrect, the true native resolution of the built-in screen is 3072x1920. This could be related to the coordinate system issue. Need to investigate WHY ydotool uses half-scale coordinates - is it related to display scaling, Wayland coordinate system, uinput device configuration, or something else? Understanding the root cause is important for portability across different computer configurations.

**Key Learnings**:
- ydotool's relative movement after absolute (0,0) uses exactly 0.5x scaling compared to KWin global coordinates
- Scaling is consistent across all screens and coordinates (both X and Y axes)
- All monitors show Scale: 1 in kscreen-doctor output, so not related to KDE display scaling
- Simple fix would be dividing coordinates by 2, but root cause needs investigation for portability
- Potential clue: laptop screen has 2x native resolution scaling (3840×2400 → 1920×1200)

## Iteration 11: Root Cause Investigation

**Status**: Investigation in progress - hypotheses developed, testing needed

**Approach**: Conducted systematic investigation to understand why ydotool uses 0.5x coordinate scaling. Gathered system information, researched Wayland/uinput coordinate systems, and developed hypotheses about the root cause.

**Progress**:
- Gathered comprehensive system information:
  - Confirmed native resolution: 3072×1920 (not 3840×2400 as previously noted)
  - Current resolution: 1920×1200 (1.6x scaling, not 2x)
  - KWin running in Xwayland operation mode despite Wayland session
- Investigated uinput device properties:
  - Device: "ydotoold virtual device" at `/dev/input/event16`
  - Capabilities: EV=7, REL=147 (supports relative movement)
  - No explicit resolution properties found in sysfs
- Researched Wayland/uinput coordinate systems:
  - libinput maps coordinates to display's logical resolution
  - Wayland compositors may apply transformations to uinput devices
  - Xwayland mode may affect coordinate interpretation
- Developed leading hypothesis: uinput device resolution mismatch (2x resolution causing 0.5x scaling)
- Created investigation artifacts:
  - `investigation-findings.md`: System information and observations
  - `investigation-hypothesis.md`: Detailed hypothesis analysis
  - `investigation-test.sh`: Test script for coordinate behavior
  - `investigation-summary.md`: Summary of investigation progress

**Why Reiterate**:
Investigation has developed strong hypotheses but hasn't confirmed the root cause. We have a test script ready but haven't executed it yet. Need to either: (1) continue investigation by running tests and examining ydotool source code, or (2) implement a fix based on current understanding (divide by 2) and test if it works across different scenarios. The investigation phase has provided good foundation, but we need to move forward with either deeper investigation or implementation.

**Key Learnings**:
- Native resolution is 3072×1920 (1.6x scaling), not 2x as initially thought
- 0.5x scaling affects ALL screens uniformly, suggesting device-level property
- uinput devices don't expose resolution properties in sysfs
- KWin reports Xwayland operation mode despite being Wayland session
- Leading hypothesis: uinput device has implicit 2x resolution causing 0.5x scaling
- Alternative hypotheses: Wayland compositor transformation or libinput coordinate mapping



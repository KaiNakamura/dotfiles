#!/bin/bash
# open-browser.sh — Open URL in browser on current virtual desktop
#
# If the preferred browser has a window on the current desktop, focus it
# and open the URL as a new tab. Otherwise, open a new browser window
# and move it to the current desktop.

# Step 2: Guard against broken file descriptors from Electron apps (Slack, Discord)
[ -e /dev/fd/1 ] || exec 1>/dev/null
[ -e /dev/fd/2 ] || exec 2>/dev/null

# Clean environment — Electron leaks GDK_BACKEND=x11 into child processes
unset GDK_BACKEND

URL="$1"
if [[ -z "$URL" ]]; then exit 1; fi

# Step 3: Browser detection via config file with fallback
BROWSER_BIN=""
RESOURCE_CLASS=""

resolve_browser() {
    local name="$1"
    case "$name" in
        chrome)
            BROWSER_BIN="google-chrome-stable"
            RESOURCE_CLASS="google-chrome"
            ;;
        firefox)
            BROWSER_BIN="firefox"
            RESOURCE_CLASS="firefox"
            ;;
        chromium)
            if command -v chromium-browser &> /dev/null; then
                BROWSER_BIN="chromium-browser"
                RESOURCE_CLASS="chromium-browser"
            elif command -v chromium &> /dev/null; then
                BROWSER_BIN="chromium"
                RESOURCE_CLASS="chromium"
            fi
            ;;
    esac
}

# Read config file
CONFIG_FILE="$HOME/.config/open-browser/browser"
if [[ -f "$CONFIG_FILE" ]]; then
    BROWSER_NAME=$(head -1 "$CONFIG_FILE" | tr -d '[:space:]')
    resolve_browser "$BROWSER_NAME"
fi

# Verify the configured browser is installed, fall back to detection if not
if [[ -z "$BROWSER_BIN" ]] || ! command -v "$BROWSER_BIN" &> /dev/null; then
    BROWSER_BIN=""
    RESOURCE_CLASS=""
    for candidate in google-chrome-stable:google-chrome firefox:firefox chromium-browser:chromium-browser chromium:chromium; do
        bin="${candidate%%:*}"
        class="${candidate##*:}"
        if command -v "$bin" &> /dev/null; then
            BROWSER_BIN="$bin"
            RESOURCE_CLASS="$class"
            break
        fi
    done
fi

if [[ -z "$BROWSER_BIN" ]]; then
    exec kde-open5 "$URL"
fi

# Fall back to direct browser invocation if qdbus is not available
if ! command -v qdbus &> /dev/null; then
    exec "$BROWSER_BIN" "$URL"
fi

# Helper: read a unique token from the journal with retries
# Usage: read_journal_token TOKEN
# Sets JOURNAL_RESULT to the matched line, or empty if not found
read_journal_token() {
    local token="$1"
    JOURNAL_RESULT=""
    journalctl --sync 2>/dev/null
    for _retry in 1 2 3; do
        JOURNAL_RESULT=$(journalctl --since "30 sec ago" --no-pager -o cat 2>/dev/null \
            | grep "$token" | tail -1)
        if [[ -n "$JOURNAL_RESULT" ]]; then
            return 0
        fi
        sleep 0.1
    done
    return 1
}

# Step 4+5: KWin detection script — check for browser on current desktop
UNIQUE_TOKEN="OPEN_BROWSER_$$_$(date +%s%N)"
SCRIPT_FILE=$(mktemp /tmp/open-browser-kwin-XXXXXX.js)
chmod 600 "$SCRIPT_FILE"
cat > "$SCRIPT_FILE" << EOF
var currentDesktop = workspace.currentDesktop;
var clients = workspace.clientList();
var found = false;
var ids = [];
for (var i = 0; i < clients.length; i++) {
    var c = clients[i];
    if (c.resourceClass !== "$RESOURCE_CLASS") continue;
    ids.push(c.internalId.toString());
    if (c.desktop !== currentDesktop && !c.onAllDesktops) continue;
    workspace.activeClient = c;
    found = true;
    break;
}
if (found) {
    console.info("$UNIQUE_TOKEN:FOUND");
} else {
    console.info("$UNIQUE_TOKEN:NOT_FOUND:" + currentDesktop + ":" + ids.join(","));
}
EOF

# Inject and run the KWin script
SCRIPT_NAME="open-browser-$$"
SCRIPT_ID=$(qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
    "$SCRIPT_FILE" "$SCRIPT_NAME" 2>/dev/null)

# Step 5: Validate SCRIPT_ID is a valid integer
if [[ ! "$SCRIPT_ID" =~ ^[0-9]+$ ]]; then
    rm -f "$SCRIPT_FILE"
    exec "$BROWSER_BIN" "$URL"
fi

qdbus org.kde.KWin "/$SCRIPT_ID" org.kde.kwin.Script.run > /dev/null 2>&1

# Step 4: Read result from journal with hardened retry
read_journal_token "$UNIQUE_TOKEN"
RESULT="$JOURNAL_RESULT"

# Cleanup
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
    "$SCRIPT_NAME" > /dev/null 2>&1
rm -f "$SCRIPT_FILE"

# Open the URL
if [[ "$RESULT" == *"FOUND"* && "$RESULT" != *"NOT_FOUND"* ]]; then
    # Browser window focused on current desktop — open as new tab
    exec "$BROWSER_BIN" "$URL"
fi

# Step 6: NOT_FOUND path — open new window and move to current desktop

# Extract target desktop and known window IDs from detection result
# Format: NOT_FOUND:<desktop>:<id1>,<id2>,...
TARGET_DESKTOP=$(echo "$RESULT" | sed "s/.*NOT_FOUND:\([0-9]*\):.*/\1/")
KNOWN_IDS=$(echo "$RESULT" | sed "s/.*NOT_FOUND:[0-9]*://")

# If parsing failed (e.g., journal read failed entirely), just open the browser
if [[ -z "$TARGET_DESKTOP" || ! "$TARGET_DESKTOP" =~ ^[0-9]+$ ]]; then
    exec "$BROWSER_BIN" --new-window "$URL"
fi

# Use flock for concurrent invocation safety — if another instance is already
# doing the move-poll, just open the browser directly
LOCK_FILE="/tmp/open-browser-move.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    exec "$BROWSER_BIN" --new-window "$URL"
fi

# Launch browser
"$BROWSER_BIN" --new-window "$URL" &

# Step 7: Poll for the new window and move it to the target desktop
MOVE_TOKEN="MOVE_$$_$(date +%s%N)"

for attempt in 1 2 3 4 5; do
    sleep 0.5
    MOVE_FILE=$(mktemp /tmp/open-browser-move-XXXXXX.js)
    chmod 600 "$MOVE_FILE"
    cat > "$MOVE_FILE" << MEOF
var known = "$KNOWN_IDS".split(",");
var target = $TARGET_DESKTOP;
var clients = workspace.clientList();
var moved = false;
for (var i = 0; i < clients.length; i++) {
    var c = clients[i];
    if (c.resourceClass !== "$RESOURCE_CLASS") continue;
    var id = c.internalId.toString();
    var isKnown = false;
    for (var j = 0; j < known.length; j++) {
        if (known[j] === id) { isKnown = true; break; }
    }
    if (!isKnown) {
        c.desktop = target;
        workspace.activeClient = c;
        moved = true;
        console.info("$MOVE_TOKEN:MOVED:" + id);
        break;
    }
}
if (!moved) console.info("$MOVE_TOKEN:NOT_YET");
MEOF

    MOVE_NAME="open-browser-move-$$"
    MOVE_ID=$(qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
        "$MOVE_FILE" "$MOVE_NAME" 2>/dev/null)

    if [[ "$MOVE_ID" =~ ^[0-9]+$ ]]; then
        qdbus org.kde.KWin "/$MOVE_ID" org.kde.kwin.Script.run > /dev/null 2>&1
        read_journal_token "$MOVE_TOKEN"
        qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
            "$MOVE_NAME" > /dev/null 2>&1
    fi

    rm -f "$MOVE_FILE"

    if [[ "$JOURNAL_RESULT" == *"MOVED"* ]]; then
        break
    fi
done

# Release lock
flock -u 9

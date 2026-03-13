#!/bin/bash
# open-browser.sh — Open URL in browser on current virtual desktop
#
# If the default browser has a window on the current desktop, focus it
# and open the URL as a new tab. Otherwise, open a new browser window.

URL="$1"
if [[ -z "$URL" ]]; then exit 1; fi

# Detect browser by finding the first available browser binary
if command -v google-chrome-stable &> /dev/null; then
    BROWSER_BIN="google-chrome-stable"
    RESOURCE_CLASS="google-chrome"
elif command -v firefox &> /dev/null; then
    BROWSER_BIN="firefox"
    RESOURCE_CLASS="firefox"
elif command -v chromium-browser &> /dev/null; then
    BROWSER_BIN="chromium-browser"
    RESOURCE_CLASS="chromium-browser"
elif command -v chromium &> /dev/null; then
    BROWSER_BIN="chromium"
    RESOURCE_CLASS="chromium"
else
    # No known browser found — fall back to kde-open5
    exec kde-open5 "$URL"
fi

# Fall back to direct browser invocation if qdbus is not available
if ! command -v qdbus &> /dev/null; then
    exec "$BROWSER_BIN" "$URL"
fi

# Write a temporary KWin script that checks for the browser on the current
# desktop and focuses it. The script prints a unique token to the journal
# so we can read back whether a window was found.
UNIQUE_TOKEN="OPEN_BROWSER_$$_$(date +%s%N)"
SCRIPT_FILE="/tmp/open-browser-kwin-$$.js"
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
}
if (found) {
    print("$UNIQUE_TOKEN:FOUND");
} else {
    print("$UNIQUE_TOKEN:NOT_FOUND:" + currentDesktop + ":" + ids.join(","));
}
EOF

# Inject and run the KWin script
SCRIPT_NAME="open-browser-$$"
SCRIPT_ID=$(qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
    "$SCRIPT_FILE" "$SCRIPT_NAME" 2>/dev/null)
qdbus org.kde.KWin "/$SCRIPT_ID" org.kde.kwin.Script.run > /dev/null 2>&1

# Wait for execution, read result from journal
sleep 0.1
RESULT=$(journalctl --since "5 sec ago" --no-pager -o cat 2>/dev/null \
    | grep "$UNIQUE_TOKEN" | tail -1)

# Cleanup
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
    "$SCRIPT_NAME" > /dev/null 2>&1
rm -f "$SCRIPT_FILE"

# Open the URL
if [[ "$RESULT" == *"FOUND"* && "$RESULT" != *"NOT_FOUND"* ]]; then
    # Browser window focused on current desktop — open as new tab
    exec "$BROWSER_BIN" "$URL"
else
    # No browser on current desktop — extract snapshot from detection result,
    # launch a new window, then poll to find and move it to the original desktop.

    # Extract target desktop and known window IDs from detection result
    # Format: NOT_FOUND:<desktop>:<id1>,<id2>,...
    TARGET_DESKTOP=$(echo "$RESULT" | sed "s/.*NOT_FOUND:\([0-9]*\):.*/\1/")
    KNOWN_IDS=$(echo "$RESULT" | sed "s/.*NOT_FOUND:[0-9]*://")

    # If parsing failed, just open the browser normally
    if [[ -z "$TARGET_DESKTOP" || ! "$TARGET_DESKTOP" =~ ^[0-9]+$ ]]; then
        exec "$BROWSER_BIN" --new-window "$URL"
    fi

    # Launch browser
    "$BROWSER_BIN" --new-window "$URL" &

    # Poll for the new window and move it to the target desktop
    MOVE_FILE="/tmp/open-browser-move-$$.js"
    MOVE_NAME="open-browser-move-$$"
    MOVE_TOKEN="MOVE_$$_$(date +%s%N)"

    for attempt in 1 2 3 4 5; do
        sleep 0.5
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
        print("$MOVE_TOKEN:MOVED:" + id);
    }
}
if (!moved) print("$MOVE_TOKEN:NOT_YET");
MEOF

        MOVE_ID=$(qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
            "$MOVE_FILE" "$MOVE_NAME" 2>/dev/null)
        qdbus org.kde.KWin "/$MOVE_ID" org.kde.kwin.Script.run > /dev/null 2>&1
        sleep 0.1
        MOVE_RESULT=$(journalctl --since "5 sec ago" --no-pager -o cat 2>/dev/null \
            | grep "$MOVE_TOKEN" | tail -1)
        qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
            "$MOVE_NAME" > /dev/null 2>&1

        if [[ "$MOVE_RESULT" == *"MOVED"* ]]; then
            break
        fi
    done
    rm -f "$MOVE_FILE"
fi

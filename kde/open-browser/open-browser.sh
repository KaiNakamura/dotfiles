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
for (var i = 0; i < clients.length; i++) {
    var c = clients[i];
    if (c.resourceClass !== "$RESOURCE_CLASS") continue;
    if (c.desktop !== currentDesktop && !c.onAllDesktops) continue;
    workspace.activeClient = c;
    found = true;
    break;
}
print("$UNIQUE_TOKEN:" + (found ? "FOUND" : "NOT_FOUND"));
EOF

# Inject and run the KWin script
SCRIPT_NAME="open-browser-$$"
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
    "$SCRIPT_FILE" "$SCRIPT_NAME" > /dev/null 2>&1
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.start > /dev/null 2>&1

# Wait for execution, read result from journal
sleep 0.1
RESULT=$(journalctl --since "5 sec ago" --no-pager -o cat 2>/dev/null \
    | grep "$UNIQUE_TOKEN" | tail -1)

# Cleanup
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
    "$SCRIPT_NAME" > /dev/null 2>&1
rm -f "$SCRIPT_FILE"

# Open the URL
if [[ "$RESULT" == *"FOUND"* ]]; then
    # Browser window focused on current desktop — open as new tab
    exec "$BROWSER_BIN" "$URL"
else
    # No browser on current desktop — install a listener that moves the new
    # window to the current desktop, then launch the browser.
    LISTENER_FILE="/tmp/open-browser-listener-$$.js"
    LISTENER_NAME="open-browser-listener-$$"
    cat > "$LISTENER_FILE" << LEOF
var targetDesktop = workspace.currentDesktop;
workspace.clientAdded.connect(function(client) {
    if (client.resourceClass === "$RESOURCE_CLASS") {
        client.desktop = targetDesktop;
    }
});
LEOF

    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
        "$LISTENER_FILE" "$LISTENER_NAME" > /dev/null 2>&1
    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.start > /dev/null 2>&1

    # Launch browser in background, wait for window to appear, then clean up
    "$BROWSER_BIN" --new-window "$URL" &
    sleep 2

    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
        "$LISTENER_NAME" > /dev/null 2>&1
    rm -f "$LISTENER_FILE"
fi

// Window List Publisher
// Stays loaded for the whole session and hands the window list to the
// org.hjkl.WindowList service whenever a window appears, goes, moves, changes
// desktop, title or minimized state. kwin-window-list reads what it was last
// handed instead of injecting a script of its own.
//
// Loading and unloading a fresh script every couple of seconds is what this
// replaces: KWin 5 crashed in its script engine under that churn, and a
// compositor crash takes every window on every desktop down with it.

// Plasma 5 names these clientList/clientAdded/desktop; Plasma 6 renamed them
// windowList/windowAdded and moved the desktop onto an array.
var plasma6 = (typeof workspace.windowList === "function");

// A drag fires a geometry change per frame and a browser retitles itself on
// every tab switch, so changes are gathered for a moment and sent once.
var SETTLE_MS = 100;
// Sent anyway on this beat, so a change no signal reported still lands, and so
// the reader can tell a live publisher from a stale snapshot.
var HEARTBEAT_MS = 5000;

function windows() {
    return plasma6 ? workspace.windowList() : workspace.clientList();
}

function desktopOf(w) {
    if (plasma6) {
        return (w.desktops && w.desktops.length === 1) ? w.desktops[0].x11DesktopNumber : -1;
    }
    return w.onAllDesktops ? -1 : w.desktop;
}

// One line per window, tab separated. No field may be empty or hold a tab: the
// reader splits on tabs, and the shell collapses a run of them into one.
function line(w) {
    var g = w.frameGeometry;
    return [w.pid, desktopOf(w), String(w.resourceClass) || "-",
            String(w.caption).replace(/\s+/g, " ") || "-",
            Math.round(g.x + g.width / 2), Math.round(g.y + g.height / 2),
            String(w.internalId), w.minimized ? 1 : 0].join("\t");
}

function publish() {
    var ws = windows();
    var out = [];
    for (var i = 0; i < ws.length; i++) {
        out.push(line(ws[i]));
    }
    callDBus("org.hjkl.WindowList", "/WindowList", "org.hjkl.WindowList",
             "Publish", out.join("\n"));
}

var settle = new QTimer();
settle.singleShot = true;
settle.interval = SETTLE_MS;
settle.timeout.connect(publish);

function changed() {
    settle.start();
}

function watch(w) {
    var signals = [w.frameGeometryChanged, w.captionChanged, w.minimizedChanged,
                   plasma6 ? w.desktopsChanged : w.desktopChanged];
    for (var i = 0; i < signals.length; i++) {
        if (signals[i]) signals[i].connect(changed);
    }
}

windows().forEach(watch);

if (plasma6) {
    workspace.windowAdded.connect(function(w) { watch(w); changed(); });
    workspace.windowRemoved.connect(changed);
} else {
    workspace.clientAdded.connect(function(w) { watch(w); changed(); });
    workspace.clientRemoved.connect(changed);
}

var heartbeat = new QTimer();
heartbeat.interval = HEARTBEAT_MS;
heartbeat.timeout.connect(publish);
heartbeat.start();

publish();

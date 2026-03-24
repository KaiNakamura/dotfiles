// HJKL Edge Guard — directional window switching with history and relaxed matching
// Supports both Plasma 5 (activeClient/clientList/geometry) and Plasma 6 (activeWindow/windowList/frameGeometry)

var TOLERANCE = 5;
var HISTORY_MAX = 16;
var _history = [];
var _moveHistory = [];
var _navigatingTo = null;
var _movingWindow = null;
var _lastOnScreen = {};   // screen → last-focused window on that screen
var opposites = { left: "right", right: "left", up: "down", down: "up" };

// Version shim: normalize Plasma 5/6 API differences
var isPlasma6 = (typeof workspace.windowList === "function");
var api = isPlasma6
    ? { getActive:   function()  { return workspace.activeWindow; },
        setActive:   function(w) { workspace.activeWindow = w; },
        getWindows:  function()  { return workspace.windowList(); },
        getGeometry: function(w) { return w.frameGeometry; },
        getScreen:   function(w) { return w.output; },
        isOnDesktop: function(w) { return w.desktops.length === 0 || w.desktops.includes(workspace.currentDesktop); },
        getScreens:  function()  { return workspace.screens; },
        getScreenGeo: function(s) { return s.geometry; },
        getWorkArea:  function(s) { return workspace.clientArea(2, s); },
        setGeometry:  function(w, g) { w.frameGeometry = g; },
        sendToScreen: function(w, s) { w.output = s; } }
    : { getActive:   function()  { return workspace.activeClient; },
        setActive:   function(w) { workspace.activeClient = w; },
        getWindows:  function()  { return workspace.clientList(); },
        getGeometry: function(w) { return w.geometry; },
        getScreen:   function(w) { return w.screen; },
        isOnDesktop: function(w) { return w.onAllDesktops || w.desktop === workspace.currentDesktop; },
        getScreens:  function()  { var s = []; for (var i = 0; i < workspace.numScreens; i++) s.push(i); return s; },
        getScreenGeo: function(s) { return workspace.clientArea(7, s, workspace.currentDesktop); },
        getWorkArea:  function(s) { return workspace.clientArea(2, s, workspace.currentDesktop); },
        setGeometry:  function(w, g) { w.geometry = g; },
        sendToScreen: function(w, s) { workspace.sendClientToScreen(w, s); } };

function isSwitchable(win) {
    if (!win) return false;
    return !win.desktopWindow
        && !win.specialWindow
        && !win.skipSwitcher
        && !win.minimized
        && !win.hidden
        && api.isOnDesktop(win);
}

function centerOf(geo) {
    return { x: geo.x + geo.width / 2, y: geo.y + geo.height / 2 };
}

function warpToScreenCenter(targetScreen) {
    var screens = api.getScreens();
    var bboxW = 0, bboxH = 0;
    for (var i = 0; i < screens.length; i++) {
        var g = api.getScreenGeo(screens[i]);
        bboxW = Math.max(bboxW, g.x + g.width);
        bboxH = Math.max(bboxH, g.y + g.height);
    }
    if (bboxW === 0 || bboxH === 0) return;
    var sg = api.getScreenGeo(targetScreen);
    var normX = ((sg.x + sg.width / 2) / bboxW).toString();
    var normY = ((sg.y + sg.height / 2) / bboxH).toString();
    callDBus("org.hjkl.MouseMover", "/MouseMover", "org.hjkl.MouseMover", "MoveTo", normX, normY);
}

// Edge-based directional filter + cone-based fallback for each direction
var directions = {
    left: {
        inDirection:  function(cg, ag) { return cg.x + cg.width <= ag.x + TOLERANCE; },
        nearestEdge:  function(cg) { return cg.x + cg.width; },
        pickBest:     function(a, b) { return a > b; },
        perpDistance:  function(cc, ac) { return Math.abs(cc.y - ac.y); },
        inCone:       function(cc, ac) { var dx = cc.x - ac.x; return dx < 0 && Math.abs(cc.y - ac.y) <= Math.abs(dx); }
    },
    right: {
        inDirection:  function(cg, ag) { return cg.x >= ag.x + ag.width - TOLERANCE; },
        nearestEdge:  function(cg) { return cg.x; },
        pickBest:     function(a, b) { return a < b; },
        perpDistance:  function(cc, ac) { return Math.abs(cc.y - ac.y); },
        inCone:       function(cc, ac) { var dx = cc.x - ac.x; return dx > 0 && Math.abs(cc.y - ac.y) <= Math.abs(dx); }
    },
    up: {
        inDirection:  function(cg, ag) { return cg.y + cg.height <= ag.y + TOLERANCE; },
        nearestEdge:  function(cg) { return cg.y + cg.height; },
        pickBest:     function(a, b) { return a > b; },
        perpDistance:  function(cc, ac) { return Math.abs(cc.x - ac.x); },
        inCone:       function(cc, ac) { var dy = cc.y - ac.y; return dy < 0 && Math.abs(cc.x - ac.x) <= Math.abs(dy); }
    },
    down: {
        inDirection:  function(cg, ag) { return cg.y >= ag.y + ag.height - TOLERANCE; },
        nearestEdge:  function(cg) { return cg.y; },
        pickBest:     function(a, b) { return a < b; },
        perpDistance:  function(cc, ac) { return Math.abs(cc.x - ac.x); },
        inCone:       function(cc, ac) { var dy = cc.y - ac.y; return dy > 0 && Math.abs(cc.x - ac.x) <= Math.abs(dy); }
    }
};

// Find best window using strict edge-adjacency, filtered by screenFilter predicate
function findBestStrict(active, ag, ac, d, screenFilter) {
    var windows = api.getWindows();
    var best = null;
    var bestEdge = 0;
    var bestPerp = Infinity;

    for (var i = 0; i < windows.length; i++) {
        var win = windows[i];
        if (win === active || !isSwitchable(win)) continue;
        if (!screenFilter(win)) continue;

        var cg = api.getGeometry(win);
        if (!d.inDirection(cg, ag)) continue;

        var edge = d.nearestEdge(cg);
        var cc = centerOf(cg);
        var perp = d.perpDistance(cc, ac);

        if (best === null || d.pickBest(edge, bestEdge)
                || (edge === bestEdge && perp < bestPerp)) {
            best = win;
            bestEdge = edge;
            bestPerp = perp;
        }
    }
    return best;
}

// Find best window using 45-degree cone, ranked by Manhattan distance
function findBestCone(active, ac, d, screenFilter) {
    var windows = api.getWindows();
    var best = null;
    var bestDist = Infinity;

    for (var i = 0; i < windows.length; i++) {
        var win = windows[i];
        if (win === active || !isSwitchable(win)) continue;
        if (!screenFilter(win)) continue;

        var cg = api.getGeometry(win);
        var cc = centerOf(cg);
        if (!d.inCone(cc, ac)) continue;

        var dist = Math.abs(cc.x - ac.x) + Math.abs(cc.y - ac.y);
        if (dist < bestDist) {
            best = win;
            bestDist = dist;
        }
    }
    return best;
}

function winName(w) {
    if (!w) return "null";
    return w.caption || w.resourceClass || "?";
}

function doActivate(win) {
    print("[HJKL] doActivate: " + winName(win) + " on screen " + api.getScreen(win));
    _navigatingTo = win;
    api.setActive(win);
}

function historyPush(win, dir) {
    if (_history.length >= HISTORY_MAX) {
        _history.shift();
    }
    _history.push({ window: win, arrivedVia: dir });
}

function switchDirection(dir) {
    print("[HJKL] === switchDirection(" + dir + ") ===");
    print("[HJKL] _navigatingTo was: " + winName(_navigatingTo));
    print("[HJKL] history len: " + _history.length);
    for (var h = 0; h < _history.length; h++) {
        print("[HJKL]   history[" + h + "]: " + winName(_history[h].window) + " via " + _history[h].arrivedVia);
    }
    _navigatingTo = null;
    _movingWindow = null;

    var active = api.getActive();
    if (!active) return;
    print("[HJKL] active: " + winName(active) + " on screen " + api.getScreen(active));
    var ag = api.getGeometry(active);
    var ac = centerOf(ag);
    var d = directions[dir];
    var activeScreen = api.getScreen(active);

    // --- Pass 1: Intra-screen strict edge-adjacency ---
    var intra = findBestStrict(active, ag, ac, d, function(win) {
        return api.getScreen(win) === activeScreen;
    });
    if (intra) {
        print("[HJKL] PASS 1 (intra-screen): " + winName(intra));
        doActivate(intra);
        return;
    }

    // --- Pass 2: Cross-screen history backtrack ---
    if (_history.length > 0) {
        var top = _history[_history.length - 1];
        print("[HJKL] Pass 2 check: dir=" + dir + " opposites[arrivedVia]=" + opposites[top.arrivedVia] + " switchable=" + isSwitchable(top.window));
        if (dir === opposites[top.arrivedVia] && isSwitchable(top.window)) {
            print("[HJKL] PASS 2 (history backtrack): " + winName(top.window));
            _history.pop();
            doActivate(top.window);
            warpToScreenCenter(api.getScreen(top.window));
            return;
        }
    } else {
        print("[HJKL] Pass 2: history empty, skipping");
    }

    // --- Pass 3: Cross-screen last-focused preference ---
    // If crossing to a screen where we previously had a focused window, prefer it
    var crossStrict = findBestStrict(active, ag, ac, d, function(win) {
        return api.getScreen(win) !== activeScreen;
    });
    if (crossStrict) {
        var targetScreen = api.getScreen(crossStrict);
        var screenKey = String(targetScreen);
        var lastWin = _lastOnScreen[screenKey];
        print("[HJKL] Pass 3: crossStrict=" + winName(crossStrict) + " lastOnScreen[" + screenKey + "]=" + winName(lastWin));
        if (lastWin && lastWin !== crossStrict && isSwitchable(lastWin)
                && api.getScreen(lastWin) === targetScreen) {
            print("[HJKL] PASS 3 (last-focused): " + winName(lastWin));
            historyPush(active, dir);
            doActivate(lastWin);
            warpToScreenCenter(targetScreen);
            return;
        }
    }

    // --- Pass 4: Cross-screen strict edge-adjacency ---
    var cross = crossStrict;
    if (cross) {
        print("[HJKL] PASS 4 (cross-screen strict): " + winName(cross));
        historyPush(active, dir);
        doActivate(cross);
        warpToScreenCenter(api.getScreen(cross));
        return;
    }

    // --- Pass 5: Cross-screen cone fallback ---
    var cone = findBestCone(active, ac, d, function(win) {
        return api.getScreen(win) !== activeScreen;
    });
    if (cone) {
        print("[HJKL] PASS 5 (cone): " + winName(cone));
        historyPush(active, dir);
        doActivate(cone);
        warpToScreenCenter(api.getScreen(cone));
        return;
    }
    print("[HJKL] No target found");
}

var NEAR_MAX_THRESHOLD = 10;

function findScreenInDirection(dir) {
    var active = api.getActive();
    if (!active) return null;
    var activeScreen = api.getScreen(active);
    var screens = api.getScreens();
    var ag = api.getScreenGeo(activeScreen);
    var ac = { x: ag.x + ag.width / 2, y: ag.y + ag.height / 2 };
    var d = directions[dir];

    for (var i = 0; i < screens.length; i++) {
        var s = screens[i];
        if (s === activeScreen) continue;
        var sg = api.getScreenGeo(s);
        if (d.inDirection(sg, ag) || d.inCone({ x: sg.x + sg.width / 2, y: sg.y + sg.height / 2 }, ac)) {
            return s;
        }
    }
    return null;
}

function isNearMaximized(win) {
    var geo = api.getGeometry(win);
    var area = api.getWorkArea(api.getScreen(win));
    return Math.abs(geo.width - area.width) <= NEAR_MAX_THRESHOLD
        && Math.abs(geo.height - area.height) <= NEAR_MAX_THRESHOLD;
}

function moveHistoryPush(win, fromScreen, dir) {
    if (_moveHistory.length >= HISTORY_MAX) _moveHistory.shift();
    _moveHistory.push({ window: win, fromScreen: fromScreen, arrivedVia: dir });
}

function doMove(win, targetScreen) {
    var wasNearMax = isNearMaximized(win);

    if (wasNearMax) {
        // Near-maximized: directly set geometry for the new screen's work area.
        // This avoids race conditions between callDBus/sendClientToScreen
        // and the maximized-window-gap script.
        var GAP = 3;
        var area = api.getWorkArea(targetScreen);
        api.setGeometry(win, {
            x: area.x + GAP,
            y: area.y + GAP,
            width: area.width - GAP * 2,
            height: area.height - GAP * 2
        });
    } else {
        api.sendToScreen(win, targetScreen);
    }
}

function moveDirection(dir) {
    _navigatingTo = null;
    _movingWindow = null;

    var win = api.getActive();
    if (!win) return;
    var fromScreen = api.getScreen(win);

    // History backtrack: if moving in the opposite direction, return to origin screen
    if (_moveHistory.length > 0) {
        var top = _moveHistory[_moveHistory.length - 1];
        if (top.window === win && dir === opposites[top.arrivedVia]) {
            _moveHistory.pop();
            _movingWindow = win;
            doMove(win, top.fromScreen);
            warpToScreenCenter(top.fromScreen);
            return;
        }
    }

    var targetScreen = findScreenInDirection(dir);
    if (targetScreen === null) return;

    _movingWindow = win;
    moveHistoryPush(win, fromScreen, dir);
    doMove(win, targetScreen);
    warpToScreenCenter(targetScreen);
}

// Shortcut registration
registerShortcut("HJKLNavLeft", "HJKL Navigate Left", "Meta+H", function() {
    switchDirection("left");
});
registerShortcut("HJKLNavDown", "HJKL Navigate Down", "Meta+J", function() {
    switchDirection("down");
});
registerShortcut("HJKLNavUp", "HJKL Navigate Up", "Meta+K", function() {
    switchDirection("up");
});
registerShortcut("HJKLNavRight", "HJKL Navigate Right", "Meta+L", function() {
    switchDirection("right");
});

registerShortcut("HJKLMoveLeft", "HJKL Move Window Left", "Meta+Shift+H", function() {
    moveDirection("left");
});
registerShortcut("HJKLMoveDown", "HJKL Move Window Down", "Meta+Shift+J", function() {
    moveDirection("down");
});
registerShortcut("HJKLMoveUp", "HJKL Move Window Up", "Meta+Shift+K", function() {
    moveDirection("up");
});
registerShortcut("HJKLMoveRight", "HJKL Move Window Right", "Meta+Shift+L", function() {
    moveDirection("right");
});

// Signal connections for history invalidation
function onWindowActivated(win) {
    try {
        if (!win) return;
        var screenKey = String(api.getScreen(win));
        print("[HJKL] onWindowActivated: " + winName(win) + " screen=" + screenKey
            + " _navigatingTo=" + winName(_navigatingTo) + " _movingWindow=" + winName(_movingWindow));
        // Always track last-focused window per screen
        _lastOnScreen[screenKey] = win;
        // Only clear navigation history on unexpected activations
        if (_navigatingTo || _movingWindow) {
            print("[HJKL]   -> guarded, history preserved (len=" + _history.length + ")");
            return;
        }
        print("[HJKL]   -> CLEARING history (was len=" + _history.length + ")");
        _history = [];
        _moveHistory = [];
    } catch(e) { print(e); }
}

function onScreensChanged() {
    try {
        _history = [];
        _moveHistory = [];
    } catch(e) { print(e); }
}

function onWindowRemoved(win) {
    try {
        if (!win) return;
        if (win === _navigatingTo) _navigatingTo = null;
        if (win === _movingWindow) _movingWindow = null;
        _history = _history.filter(function(entry) {
            return entry.window !== win;
        });
        _moveHistory = _moveHistory.filter(function(entry) {
            return entry.window !== win;
        });
        // Clean up last-on-screen entries for this window
        for (var key in _lastOnScreen) {
            if (_lastOnScreen[key] === win) delete _lastOnScreen[key];
        }
    } catch(e) { print(e); }
}

if (isPlasma6) {
    workspace.windowActivated.connect(onWindowActivated);
    workspace.screensChanged.connect(onScreensChanged);
    workspace.windowRemoved.connect(onWindowRemoved);
} else {
    workspace.clientActivated.connect(onWindowActivated);
    workspace.numberScreensChanged.connect(onScreensChanged);
}

// HJKL Edge Guard — directional window switching with history and relaxed matching
// Supports both Plasma 5 (activeClient/clientList/geometry) and Plasma 6 (activeWindow/windowList/frameGeometry)

var TOLERANCE = 5;
var HISTORY_MAX = 16;
var _history = [];
var _moveHistory = [];
var _navigatingTo = null;
var _movingWindow = null;
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

        if (best === null || d.pickBest(edge, bestEdge) || (edge === bestEdge && perp < bestPerp)) {
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

function doActivate(win) {
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
    var active = api.getActive();
    if (!active) return;
    var ag = api.getGeometry(active);
    var ac = centerOf(ag);
    var d = directions[dir];
    var activeScreen = api.getScreen(active);

    // --- Pass 1: Intra-screen strict edge-adjacency ---
    var intra = findBestStrict(active, ag, ac, d, function(win) {
        return api.getScreen(win) === activeScreen;
    });
    if (intra) {
        doActivate(intra);
        return;
    }

    // --- Pass 2: Cross-screen history backtrack ---
    if (_history.length > 0) {
        var top = _history[_history.length - 1];
        if (dir === opposites[top.arrivedVia] && isSwitchable(top.window)) {
            _history.pop();
            doActivate(top.window);
            return;
        }
    }

    // --- Pass 3: Cross-screen strict edge-adjacency ---
    var cross = findBestStrict(active, ag, ac, d, function(win) {
        return api.getScreen(win) !== activeScreen;
    });
    if (cross) {
        historyPush(active, dir);
        doActivate(cross);
        return;
    }

    // --- Pass 4: Cross-screen cone fallback ---
    var cone = findBestCone(active, ac, d, function(win) {
        return api.getScreen(win) !== activeScreen;
    });
    if (cone) {
        historyPush(active, dir);
        doActivate(cone);
        return;
    }
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
            return;
        }
    }

    var targetScreen = findScreenInDirection(dir);
    if (targetScreen === null) return;

    _movingWindow = win;
    moveHistoryPush(win, fromScreen, dir);
    doMove(win, targetScreen);
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
        if (win === _navigatingTo) {
            _navigatingTo = null;
            return;
        }
        if (win === _movingWindow) {
            _movingWindow = null;
            return;
        }
        _navigatingTo = null;
        _movingWindow = null;
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

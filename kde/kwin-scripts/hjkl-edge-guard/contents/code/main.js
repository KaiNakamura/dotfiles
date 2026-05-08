// HJKL Edge Guard: directional window switching with history and relaxed matching
// Supports both Plasma 5 (activeClient/clientList/geometry) and Plasma 6 (activeWindow/windowList/frameGeometry)

var TOLERANCE = 5;
var HISTORY_MAX = 16;
var _history = [];
var _moveHistory = [];
var _navigatingTo = null;
var _movingWindow = null;
var _activationOrder = {}; // winKey -> monotonic tick of last activation (z-order proxy)
var _activationTick = 0;
var _idCounter = 0;
var opposites = { left: "right", right: "left", up: "down", down: "up" };

function winKey(win) {
    if (!win) return null;
    if (win.internalId) return String(win.internalId);
    if (win.__hjklId) return win.__hjklId;
    win.__hjklId = "h" + (++_idCounter);
    return win.__hjklId;
}

function stampActivation(win) {
    var k = winKey(win);
    if (k === null) return;
    _activationOrder[k] = ++_activationTick;
    print("[hjkl] activated key=" + k + " tick=" + _activationTick + " caption=" + (win.caption || ""));
}

function activationTick(win) {
    var k = winKey(win);
    if (k === null) return 0;
    return _activationOrder[k] || 0;
}

// Version shim: normalize Plasma 5/6 API differences
var isPlasma6 = (typeof workspace.windowList === "function");
try {
    var _stackProbe = workspace.stackingOrder;
    print("[hjkl] probe: workspace.stackingOrder type=" + (typeof _stackProbe)
        + " length=" + (_stackProbe && _stackProbe.length !== undefined ? _stackProbe.length : "n/a"));
} catch(e) {
    print("[hjkl] probe: workspace.stackingOrder threw " + e);
}
try {
    var _wsKeys = [];
    for (var _k in workspace) _wsKeys.push(_k);
    print("[hjkl] probe: workspace keys = " + _wsKeys.sort().join(","));
} catch(e) { print("[hjkl] probe: workspace keys threw " + e); }
try {
    var _wins = (typeof workspace.windowList === "function") ? workspace.windowList() : [];
    if (_wins.length > 0) {
        var _w0 = _wins[0];
        var _wKeys = [];
        for (var _kk in _w0) _wKeys.push(_kk);
        print("[hjkl] probe: window[0] keys = " + _wKeys.sort().join(","));
    }
} catch(e) { print("[hjkl] probe: window keys threw " + e); }
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
    var bestTick = -1;

    for (var i = 0; i < windows.length; i++) {
        var win = windows[i];
        if (win === active || !isSwitchable(win)) continue;
        if (!screenFilter(win)) continue;

        var cg = api.getGeometry(win);
        if (!d.inDirection(cg, ag)) continue;

        var edge = d.nearestEdge(cg);
        var cc = centerOf(cg);
        var perp = d.perpDistance(cc, ac);
        var tick = activationTick(win);

        var replace = false;
        if (best === null) replace = true;
        else if (d.pickBest(edge, bestEdge)) replace = true;
        else if (edge === bestEdge && perp < bestPerp) replace = true;
        else if (edge === bestEdge && perp === bestPerp && tick > bestTick) {
            replace = true;
            print("[hjkl] strict tiebreak: chose key=" + winKey(win) + " tick=" + tick
                + " over key=" + winKey(best) + " tick=" + bestTick);
        }

        if (replace) {
            best = win;
            bestEdge = edge;
            bestPerp = perp;
            bestTick = tick;
        }
    }
    return best;
}

// Find best window using 45-degree cone, ranked by Manhattan distance
function findBestCone(active, ac, d, screenFilter) {
    var windows = api.getWindows();
    var best = null;
    var bestDist = Infinity;
    var bestTick = -1;

    for (var i = 0; i < windows.length; i++) {
        var win = windows[i];
        if (win === active || !isSwitchable(win)) continue;
        if (!screenFilter(win)) continue;

        var cg = api.getGeometry(win);
        var cc = centerOf(cg);
        if (!d.inCone(cc, ac)) continue;

        var dist = Math.abs(cc.x - ac.x) + Math.abs(cc.y - ac.y);
        var tick = activationTick(win);

        var replace = false;
        if (best === null) replace = true;
        else if (dist < bestDist) replace = true;
        else if (dist === bestDist && tick > bestTick) {
            replace = true;
            print("[hjkl] cone tiebreak: chose key=" + winKey(win) + " tick=" + tick
                + " over key=" + winKey(best) + " tick=" + bestTick);
        }

        if (replace) {
            best = win;
            bestDist = dist;
            bestTick = tick;
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

// Returns the screen containing point (x, y), or the first screen as fallback.
function getScreenAtPoint(x, y) {
    var screens = api.getScreens();
    for (var i = 0; i < screens.length; i++) {
        var g = api.getScreenGeo(screens[i]);
        if (x >= g.x && x < g.x + g.width && y >= g.y && y < g.y + g.height) {
            return screens[i];
        }
    }
    return screens.length > 0 ? screens[0] : null;
}

function switchDirection(dir) {
    _navigatingTo = null;
    _movingWindow = null;

    var active = api.getActive();
    var ag, ac, activeScreen;
    var bootstrapped = false;

    if (!active || !isSwitchable(active)) {
        // No valid active window: use cursor position as the navigation anchor.
        // This lets directional passes find windows relative to where the cursor is,
        // rather than relative to a bootstrap window that may be on the wrong screen.
        var cursor = workspace.cursorPos;
        ag = { x: cursor.x, y: cursor.y, width: 0, height: 0 };
        ac = { x: cursor.x, y: cursor.y };
        activeScreen = getScreenAtPoint(cursor.x, cursor.y);
        active = null;
        bootstrapped = true;
    } else {
        ag = api.getGeometry(active);
        ac = centerOf(ag);
        activeScreen = api.getScreen(active);
    }

    print("[hjkl] switchDirection dir=" + dir
        + " active=" + (active ? winKey(active) : "null")
        + " activeScreen=" + String(activeScreen)
        + " bootstrapped=" + bootstrapped);

    var d = directions[dir];

    // Intra-screen strict edge-adjacency
    var intra = findBestStrict(active, ag, ac, d, function(win) {
        return activeScreen !== null && api.getScreen(win) === activeScreen;
    });
    if (intra) {
        print("[hjkl] -> intra key=" + winKey(intra) + " tick=" + activationTick(intra));
        doActivate(intra);
        return;
    }

    // Cross-screen history backtrack (skip when bootstrapped -- no prior window)
    if (!bootstrapped && _history.length > 0) {
        var top = _history[_history.length - 1];
        if (dir === opposites[top.arrivedVia] && isSwitchable(top.window)) {
            _history.pop();
            print("[hjkl] -> backtrack key=" + winKey(top.window));
            doActivate(top.window);
            warpToScreenCenter(api.getScreen(top.window));
            return;
        }
    }

    // Cross-screen strict edge-adjacency (activation-order tiebreaker handles overlap)
    var cross = findBestStrict(active, ag, ac, d, function(win) {
        return activeScreen === null || api.getScreen(win) !== activeScreen;
    });
    if (cross) {
        if (!bootstrapped) historyPush(active, dir);
        print("[hjkl] -> cross-strict key=" + winKey(cross) + " tick=" + activationTick(cross));
        doActivate(cross);
        warpToScreenCenter(api.getScreen(cross));
        return;
    }

    // Cross-screen cone fallback
    var cone = findBestCone(active, ac, d, function(win) {
        return activeScreen === null || api.getScreen(win) !== activeScreen;
    });
    if (cone) {
        if (!bootstrapped) historyPush(active, dir);
        print("[hjkl] -> cross-cone key=" + winKey(cone) + " tick=" + activationTick(cone));
        doActivate(cone);
        warpToScreenCenter(api.getScreen(cone));
        return;
    }

    print("[hjkl] -> no candidate found");
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

function onDesktopChanged() {
    try {
        _history = [];
        _moveHistory = [];
    } catch(e) {}
}

function onWindowActivated(win) {
    try {
        if (!win) return;
        stampActivation(win);
        if (_navigatingTo || _movingWindow) return;
        _history = [];
        _moveHistory = [];
    } catch(e) {}
}

function onScreensChanged() {
    try {
        _history = [];
        _moveHistory = [];
    } catch(e) {}
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
        var k = winKey(win);
        if (k !== null && _activationOrder.hasOwnProperty(k)) delete _activationOrder[k];
    } catch(e) {}
}

if (isPlasma6) {
    workspace.windowActivated.connect(onWindowActivated);
    workspace.screensChanged.connect(onScreensChanged);
    workspace.windowRemoved.connect(onWindowRemoved);
    workspace.currentDesktopChanged.connect(onDesktopChanged);
} else {
    workspace.clientActivated.connect(onWindowActivated);
    workspace.numberScreensChanged.connect(onScreensChanged);
    workspace.currentDesktopChanged.connect(onDesktopChanged);
}

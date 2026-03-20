// Kai Keybinds - KWin Script
// Custom workspace keybinds for KDE Plasma (5.27+ and 6.x)

// --- Plasma 5/6 Compatibility Layer ---

var isKDE6 = typeof workspace.windowList === "function";

function getWindowList() {
    return isKDE6 ? workspace.windowList() : workspace.clientList();
}

function getCurrentDesktop() {
    if (isKDE6) {
        return workspace.desktops.indexOf(workspace.currentDesktop) + 1;
    }
    return workspace.currentDesktop;
}

function switchToDesktop(n) {
    if (isKDE6) {
        workspace.currentDesktop = workspace.desktops[n - 1];
    } else {
        workspace.currentDesktop = n;
    }
}

function moveWindowToDesktop(win, n) {
    if (isKDE6) {
        win.desktops = [workspace.desktops[n - 1]];
    } else {
        win.desktop = n;
    }
}

function getWindowDesktop(win) {
    if (isKDE6) {
        return win.desktops.length > 0
            ? workspace.desktops.indexOf(win.desktops[0]) + 1
            : -1;
    }
    return win.desktop;
}

function isOnAllDesktops(win) {
    if (isKDE6) {
        return win.desktops.length === 0;
    }
    return win.onAllDesktops;
}

// --- Move Current Desktop Windows to Desktop N (Meta+Ctrl+1-0) ---

for (var i = 1; i <= 10; i++) {
    (function(n) {
        var key = n === 10 ? "0" : String(n);
        registerShortcut(
            "MoveAllToDesktop" + n,
            "Move Current Desktop Windows to Desktop " + n,
            "Meta+Ctrl+" + key,
            function() {
                var current = getCurrentDesktop();
                if (current === n) return;
                var windows = getWindowList();
                for (var j = 0; j < windows.length; j++) {
                    var win = windows[j];
                    if (win.normalWindow && !isOnAllDesktops(win) && getWindowDesktop(win) === current) {
                        moveWindowToDesktop(win, n);
                    }
                }
                switchToDesktop(n);
            }
        );
    })(i);
}

// --- Swap Windows Between Current Desktop and Desktop N (Meta+Ctrl+Shift+1-0) ---

// KDE interprets Shift+number as the shifted symbol, not Shift+digit
var shiftedKeys = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"];

for (var i = 1; i <= 10; i++) {
    (function(n) {
        var key = shiftedKeys[n - 1];
        registerShortcut(
            "SwapWithDesktop" + n,
            "Swap Windows with Desktop " + n,
            "Meta+Ctrl+" + key,
            function() {
                var current = getCurrentDesktop();
                if (current === n) return;

                var windows = getWindowList();
                var fromCurrent = [];
                var fromTarget = [];

                for (var j = 0; j < windows.length; j++) {
                    var win = windows[j];
                    if (!win.normalWindow || isOnAllDesktops(win)) continue;
                    var desk = getWindowDesktop(win);
                    if (desk === current) fromCurrent.push(win);
                    else if (desk === n) fromTarget.push(win);
                }

                for (var j = 0; j < fromCurrent.length; j++) {
                    moveWindowToDesktop(fromCurrent[j], n);
                }
                for (var j = 0; j < fromTarget.length; j++) {
                    moveWindowToDesktop(fromTarget[j], current);
                }

                switchToDesktop(n);
            }
        );
    })(i);
}

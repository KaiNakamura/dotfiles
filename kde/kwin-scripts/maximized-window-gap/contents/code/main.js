// Maximized Window Gap
// When a window is maximized, unmaximize it and resize to fill the screen
// minus a small gap. This prevents KWin from suppressing the shadow layer
// (which contains the Klassy thin window outline).

var GAP = 3;
var processing = {};

function applyGap(client) {
    if (!client || client.fullScreen) return;
    if (!client.normalWindow) return;

    var area = workspace.clientArea(KWin.MaximizeArea, client);

    // Check if window is at or near maximized size
    var geo = client.geometry;
    var isMaxedH = Math.abs(geo.width - area.width) <= GAP * 2;
    var isMaxedV = Math.abs(geo.height - area.height) <= GAP * 2;
    if (!isMaxedH && !isMaxedV) return;

    // Prevent re-entrant calls
    var id = client.windowId;
    if (processing[id]) return;
    processing[id] = true;

    var newGeo = {
        x: area.x + GAP,
        y: area.y + GAP,
        width: area.width - GAP * 2,
        height: area.height - GAP * 2
    };

    // Unmaximize first so KWin doesn't treat it as MaximizeFull
    client.setMaximize(false, false);
    client.geometry = newGeo;

    // Allow processing again after a short delay
    var timer = new QTimer();
    timer.singleShot = true;
    timer.interval = 100;
    timer.timeout.connect(function() {
        delete processing[id];
    });
    timer.start();
}

function onMaximizedChanged(client, h, v) {
    if (h || v) {
        applyGap(client);
    }
}

function setupClient(client) {
    client.clientMaximizedStateChanged.connect(onMaximizedChanged);
}

// Connect to existing clients and apply gap to any already maximized
workspace.clientList().forEach(function(client) {
    setupClient(client);
    applyGap(client);
});

// Connect to new clients, apply gap after a delay so geometry is settled
workspace.clientAdded.connect(function(client) {
    setupClient(client);
    var timer = new QTimer();
    timer.singleShot = true;
    timer.interval = 50;
    timer.timeout.connect(function() {
        applyGap(client);
    });
    timer.start();
});

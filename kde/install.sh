#!/bin/bash

# Check if running KDE Plasma
if [[ "$XDG_CURRENT_DESKTOP" != *"KDE"* ]]; then
    echo "Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Skipping KDE configuration"
    exit 1
fi

echo "KDE detected. Proceeding with configuration..."

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install Klassy window decoration (for active window outline)
if [[ -f "$WORKDIR/install-klassy.sh" ]]; then
    echo "Installing Klassy..."
    chmod +x "$WORKDIR/install-klassy.sh"
    "$WORKDIR/install-klassy.sh"
else
    echo "install-klassy.sh not found in $WORKDIR"
fi

# Configure shortcuts
if [[ -f "$WORKDIR/apply-kksrc.sh" ]]; then
    echo "Configuring keyboard shortcuts..."
    chmod +x "$WORKDIR/apply-kksrc.sh"
    "$WORKDIR/apply-kksrc.sh"
else
    echo "apply-kksrc.sh not found in $WORKDIR"
fi

# Configure settings
if [[ -f "$WORKDIR/settings.sh" ]]; then
    echo "Configuring settings..."
    chmod +x "$WORKDIR/settings.sh"
    "$WORKDIR/settings.sh"
else
    echo "settings.sh not found in $WORKDIR"
fi

# Configure scripts
if [[ -f "$WORKDIR/apply-scripts.sh" ]]; then
    echo "Configuring scripts..."
    chmod +x "$WORKDIR/apply-scripts.sh"
    "$WORKDIR/apply-scripts.sh"
else
    echo "apply-scripts.sh not found in $WORKDIR"
fi

# Configure open-browser handler
if [[ -f "$WORKDIR/apply-open-browser.sh" ]]; then
    echo "Configuring open-browser handler..."
    chmod +x "$WORKDIR/apply-open-browser.sh"
    "$WORKDIR/apply-open-browser.sh"
else
    echo "apply-open-browser.sh not found in $WORKDIR"
fi

# Install dotool (cursor movement tool for Wayland)
echo "Installing dotool..."
if ! command -v dotool &> /dev/null && ! [[ -x "$HOME/.local/bin/dotool" ]]; then
    if ! command -v go &> /dev/null; then
        echo "Error: Go is required to build dotool but not found."
        echo "Install Go first: https://go.dev/dl/"
        exit 1
    fi
    if ! pkg-config --exists xkbcommon 2>/dev/null; then
        echo "Installing libxkbcommon-dev (required for dotool)..."
        sudo apt-get install -y libxkbcommon-dev
    fi
    DOTOOL_BUILD=$(mktemp -d)
    git clone https://git.sr.ht/~geb/dotool "$DOTOOL_BUILD"
    (cd "$DOTOOL_BUILD" && go build -o dotool .)
    mkdir -p "$HOME/.local/bin"
    cp "$DOTOOL_BUILD/dotool" "$HOME/.local/bin/dotool"
    cp "$DOTOOL_BUILD/dotoold" "$HOME/.local/bin/dotoold"
    cp "$DOTOOL_BUILD/dotoolc" "$HOME/.local/bin/dotoolc"
    chmod +x "$HOME/.local/bin/dotool" "$HOME/.local/bin/dotoold" "$HOME/.local/bin/dotoolc"
    rm -rf "$DOTOOL_BUILD"
    echo "dotool built and installed to ~/.local/bin/"
else
    echo "dotool already installed."
fi

# Start dotoold (keeps the virtual input device alive for fast dotoolc calls)
if ! pgrep -x dotoold > /dev/null 2>&1; then
    echo "Starting dotoold..."
    "$HOME/.local/bin/dotoold" &
    sleep 1
fi

# Install mouse mover D-Bus service (bridges KWin script to dotool)
echo "Installing mouse mover D-Bus service..."
MOUSE_MOVER_SRC="$WORKDIR/scripts/mouse-mover-service.py"
MOUSE_MOVER_DST="$HOME/.local/bin/mouse-mover-service.py"
DBUS_SERVICE_SRC="$WORKDIR/dbus-services/org.hjkl.MouseMover.service"
DBUS_SERVICE_DST="$HOME/.local/share/dbus-1/services/org.hjkl.MouseMover.service"

mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/dbus-1/services"
cp "$MOUSE_MOVER_SRC" "$MOUSE_MOVER_DST"
chmod +x "$MOUSE_MOVER_DST"

# Write D-Bus service file with resolved path
cat > "$DBUS_SERVICE_DST" << EOF
[D-BUS Service]
Name=org.hjkl.MouseMover
Exec=/usr/bin/python3 $MOUSE_MOVER_DST
EOF

# Kill any existing mouse mover service so D-Bus restarts it with new code
pkill -f "mouse-mover-service" 2>/dev/null || true
echo "Mouse mover D-Bus service installed."

# Install KWin scripts
KWIN_SCRIPT_DIR="$WORKDIR/kwin-scripts/hjkl-edge-guard"
if [[ -d "$KWIN_SCRIPT_DIR" ]]; then
    echo "Installing KWin scripts..."

    # Detect kpackagetool version
    if command -v kpackagetool6 &> /dev/null; then
        KPKG=kpackagetool6
        KWRITECONFIG=kwriteconfig6
    elif command -v kpackagetool5 &> /dev/null; then
        KPKG=kpackagetool5
        KWRITECONFIG=kwriteconfig5
    else
        echo "Error: Neither kpackagetool5 nor kpackagetool6 found."
        exit 1
    fi

    # Clean up stale state from previous installs/debugging
    echo "Cleaning up stale state..."
    rm -rf "$HOME/.local/share/kwin/scripts/hjkl-nav"
    "$KWRITECONFIG" --file kwinrc --group Plugins --key hjkl-navEnabled --delete 2>/dev/null || true
    "$KPKG" --type KWin/Script -r hjkl-edge-guard 2>/dev/null || true

    # Remove stale shortcut entries from kglobalshortcutsrc config file
    /usr/bin/python3 -c "
import configparser, os

path = os.path.expanduser('~/.config/kglobalshortcutsrc')
if os.path.exists(path):
    cfg = configparser.RawConfigParser()
    cfg.optionxform = str  # preserve case
    cfg.read(path)
    changed = False
    # Remove stale kwin section entries from previous naming schemes
    if cfg.has_section('kwin'):
        stale = [k for k in cfg.options('kwin') if k.startswith('HJKLSwitch') or k.startswith('HJKLTest')]
        for k in stale:
            cfg.remove_option('kwin', k)
            print(f'  Removed stale shortcut: {k}')
            changed = True
    # Remove old desktop file shortcut sections from config file
    for section in ['kwin-move-screen-left.desktop', 'kwin-move-screen-right.desktop',
                    'kwin-move-screen-up.desktop', 'kwin-move-screen-down.desktop']:
        if cfg.has_section(section):
            cfg.remove_section(section)
            print(f'  Removed old desktop shortcut section: {section}')
            changed = True
    if changed:
        with open(path, 'w') as f:
            cfg.write(f)
"
    # Remove old move-screen desktop files and scripts (now handled by KWin script)
    rm -f "$HOME/.local/share/applications/kwin-move-screen-"*.desktop
    rm -f "$HOME/.local/bin/kwin-move-screen-"*.sh

    # Fresh install the plugin
    "$KPKG" --type KWin/Script -i "$KWIN_SCRIPT_DIR"

    # Toggle the plugin off then on to force KWin to reload it
    "$KWRITECONFIG" --file kwinrc --group Plugins --key hjkl-edge-guardEnabled false
    qdbus org.kde.KWin /KWin reconfigure
    sleep 1
    "$KWRITECONFIG" --file kwinrc --group Plugins --key hjkl-edge-guardEnabled true
    qdbus org.kde.KWin /KWin reconfigure

    # Force-assign Meta+HJKL to the plugin shortcuts via D-Bus
    # registerShortcut defaults are rejected if keys are already taken,
    # so we assign directly in kglobalaccel's memory
    echo "Assigning HJKL shortcuts..."
    /usr/bin/python3 -c "
import dbus

bus = dbus.SessionBus()
proxy = bus.get_object('org.kde.kglobalaccel', '/kglobalaccel')
iface = dbus.Interface(proxy, 'org.kde.KGlobalAccel')

# Unregister old desktop file shortcuts that may be claiming Meta+Shift+HJKL
old_components = [
    'kwin-move-screen-left.desktop',
    'kwin-move-screen-right.desktop',
    'kwin-move-screen-up.desktop',
    'kwin-move-screen-down.desktop',
]
for comp in old_components:
    try:
        result = iface.unregister(comp, '_launch')
        if result:
            print(f'  Freed stale shortcut: {comp}')
    except Exception:
        pass

META = 0x10000000
SHIFT = 0x02000000
shortcuts = {
    'HJKLNavLeft':   (META | 0x48, 'HJKL Navigate Left'),
    'HJKLNavDown':   (META | 0x4A, 'HJKL Navigate Down'),
    'HJKLNavUp':     (META | 0x4B, 'HJKL Navigate Up'),
    'HJKLNavRight':  (META | 0x4C, 'HJKL Navigate Right'),
    'HJKLMoveLeft':  (META | SHIFT | 0x48, 'HJKL Move Window Left'),
    'HJKLMoveDown':  (META | SHIFT | 0x4A, 'HJKL Move Window Down'),
    'HJKLMoveUp':    (META | SHIFT | 0x4B, 'HJKL Move Window Up'),
    'HJKLMoveRight': (META | SHIFT | 0x4C, 'HJKL Move Window Right'),
}

for action, (key, label) in shortcuts.items():
    action_id = dbus.Array(['kwin', action, 'KWin', label], signature='s')
    keys = dbus.Array([dbus.Int32(key)], signature='i')
    iface.setForeignShortcut(action_id, keys)
    print(f'  {label} -> {action}')
"

    echo "KWin script installed and enabled."
    echo "NOTE: You must log out and back in for changes to take effect."
else
    echo "KWin script directory not found at $KWIN_SCRIPT_DIR"
fi
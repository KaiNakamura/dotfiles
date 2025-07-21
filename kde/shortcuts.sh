#!/bin/bash

# TODO: Update (or abandon, I might move away from KDE, but Hyprland keybinds take precedence over these)

# ===== KWin Shortcuts =====

# `kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "KEY_NAME" "BIND,DEFAULT,DESCRIPTION"`

# Unbind Meta+F5 and Meta+F6
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "MoveMouseToFocus" "none,Meta+F5,Move Mouse to Focus"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "MoveMouseToCenter" "none,Meta+F6,Move Mouse to Center"

# Switch to Desktop 1-9: Meta+F1-9
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 1" "Meta+F1,Ctrl+F1,Switch to Desktop 1"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 2" "Meta+F2,Ctrl+F2,Switch to Desktop 2"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 3" "Meta+F3,Ctrl+F3,Switch to Desktop 3"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 4" "Meta+F4,Ctrl+F4,Switch to Desktop 4"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 5" "Meta+F5,,Switch to Desktop 5"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 6" "Meta+F6,,Switch to Desktop 6"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 7" "Meta+F7,,Switch to Desktop 7"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 8" "Meta+F8,,Switch to Desktop 8"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 9" "Meta+F9,,Switch to Desktop 9"

# Move Window One Screen Left/Right/Up/Down: Meta+Left/Right/Up/Down
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window One Screen to the Left" "Meta+Left,,Move Window One Screen to the Left"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window One Screen to the Right" "Meta+Right,,Move Window One Screen to the Right"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window One Screen Up" "Meta+Up,,Move Window One Screen Up"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window One Screen Down" "Meta+Down,,Move Window One Screen Down"

# Quick Tile Window to the Left/Right/Top/Bottom: Meta+Shift+Left/Right/Up/Down
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Left" "Meta+Shift+Left,Meta+Left,Quick Tile Window to the Left"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Right" "Meta+Shift+Right,Meta+Right,Quick Tile Window to the Right"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "Meta+Shift+Up,Meta+Up,Quick Tile Window to the Top"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Bottom" "Meta+Shift+Down,Meta+Down,Quick Tile Window to the Bottom"

# Switch to Window Left/Right/Above/Below: Alt+Left/Right/Up/Down
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch Window Left" "Alt+Left,Meta+Alt+Left,Switch to Window to the Left"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch Window Right" "Alt+Right,Meta+Alt+Right,Switch to Window to the Right"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch Window Up" "Alt+Up,Meta+Alt+Up,Switch to Window Above"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch Window Down" "Alt+Down,Meta+Alt+Down,Switch to Window Below"

# Maximize Window: Meta+Alt+Up and Alt+Enter
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+Alt+Up"$'\t'"Alt+Return,Meta+PgUp,Maximize Window"

# Minimize Window: Meta+Alt+Down
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Minimize" "Meta+Alt+Down,Meta+PgDown,Minimize Window"

# ===== Application Shortcuts =====

# Launch Kitty: Ctrl+Alt+T and Meta+N
kwriteconfig6 --file kglobalshortcutsrc --group "services/kitty.desktop" --key "_launch" "Ctrl+Alt+T"$'\t'"Meta+N"

# Disable Konsole shortcut
kwriteconfig6 --file kglobalshortcutsrc --group "services/org.kde.konsole.desktop" --key "_launch" "none"

# Launch Firefox: Meta+F
kwriteconfig6 --file kglobalshortcutsrc --group "services/firefox_firefox.desktop" --key "_launch" "Meta+F"

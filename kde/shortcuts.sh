#!/bin/bash

# Switch to Desktop 1-4: Meta + F1/F2/F3/F4
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 1" "Meta+F1,Ctrl+F1,Switch to Desktop 1"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 2" "Meta+F2,Ctrl+F2,Switch to Desktop 2"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 3" "Meta+F3,Ctrl+F3,Switch to Desktop 3"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 4" "Meta+F4,Ctrl+F4,Switch to Desktop 4"

# Move Window One Screen Left/Right/Up/Down: Meta + Left/Right/Up/Down
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window One Screen to the Left" "Meta+Left,,Move Window One Screen to the Left"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window One Screen to the Right" "Meta+Right,,Move Window One Screen to the Right"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window One Screen Up" "Meta+Up,,Move Window One Screen Up"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window One Screen Down" "Meta+Down,,Move Window One Screen Down"

# Quick Tile Window to the Left/Right/Top/Bottom: Meta + Shift + Left/Right/Up/Down
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Left" "Meta+Shift+Left,Meta+Left,Quick Tile Window to the Left"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Right" "Meta+Shift+Right,Meta+Right,Quick Tile Window to the Right"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "Meta+Shift+Up,Meta+Up,Quick Tile Window to the Top"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Bottom" "Meta+Shift+Down,Meta+Down,Quick Tile Window to the Bottom"

# Switch to Window Left/Right/Above/Below: Alt + Left/Right/Up/Down
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch Window Left" "Alt+Left,Meta+Alt+Left,Switch to Window to the Left"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch Window Right" "Alt+Right,Meta+Alt+Right,Switch to Window to the Right"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch Window Up" "Alt+Up,Meta+Alt+Up,Switch to Window Above"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch Window Down" "Alt+Down,Meta+Alt+Down,Switch to Window Below"

# Maximize Window: Meta + Alt + Up and Alt + Enter
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+Alt+Up"$'\t'"Alt+Return,Meta+PgUp,Maximize Window"

# Minimize Window: Meta + Alt + Down
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Minimize" "Meta+Alt+Down,Meta+PgDown,Minimize Window"
#!/bin/bash

# NOTE: Use `kcmshell6 --list` to see available modules, some other useful commands:
# `kreadconfig6 --file <file_name> --group <group_name> --key <key_name>`
# `kwriteconfig6 --file <file_name> --group <group_name> --key <key_name> <value>`

# ===== Appearance =====

# Theme: Breeze Dark
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop

# Resolution Scale
kwriteconfig6 --file kwinrc --group Xwayland --key Scale 1.75

# ===== Behavior =====

# On login, always start with an empty session
kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession

# Number of Virtual Desktops
kwriteconfig6 --file kwinrc --group Desktops --key Number 4


# ===== Default Applications =====

# Kitty
kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ~/.local/kitty.app/bin/kitty
kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop

# Firefox
# TODO: Disabling for now, want to figure out a way to toggle between Firefox and Chrome (I use Firefox for personal and Chrome for work)
# kwriteconfig6 --file kdeglobals --group General --key BrowserApplication firefox_firefox.desktop
# kwriteconfig6 --file mimeapps.list --group "Default Applications" --key application/pdf firefox_firefox.desktop;
# kwriteconfig6 --file mimeapps.list --group "Default Applications" --key text/html firefox_firefox.desktop;
# kwriteconfig6 --file mimeapps.list --group "Default Applications" --key x-scheme-handler/http firefox_firefox.desktop;
# kwriteconfig6 --file mimeapps.list --group "Default Applications" --key x-scheme-handler/https firefox_firefox.desktop;
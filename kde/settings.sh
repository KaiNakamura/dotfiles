#!/bin/bash

# NOTE: Use `kcmshell6 --list` to see available modules, some other useful commands:
# `kreadconfig6 --file <file_name> --group <group_name> --key <key_name>`
# `kwriteconfig6 --file <file_name> --group <group_name> --key <key_name> <value>`

# Config settings
# - Pointer speed: -0.40
# - Wallpaper: Mountain
# - Login screen, also set to Mountain (open containing folder in wallpaper settings `/usr/share/wallpapers/Mountain/contents/images_dark/`)
# - Splash Screen:
# 	- Originally I had this on "none" but maybe this is causing issues with the graphics loading
# 	- Keeping it on default for now
# - Taskbar
# 	- Konsole
# 	- VS Code
# 	- Chrome (or Firefox, depends on personal vs. work)
# 	- Slack

# On login, always start with an empty session
kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession

# Theme: Breeze Dark
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop

# Number of Virtual Desktops
kwriteconfig6 --file kwinrc --group Desktops --key Number 1

# Resolution Scale
kwriteconfig6 --file kwinrc --group Xwayland --key Scale 1.75

# Default Applications
kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ~/.local/kitty.app/bin/kitty
kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop

kwriteconfig6 --file kdeglobals --group General --key BrowserApplication firefox_firefox.desktop
kwriteconfig6 --file mimeapps.list --group "Default Applications" --key application/pdf firefox_firefox.desktop;
kwriteconfig6 --file mimeapps.list --group "Default Applications" --key text/html firefox_firefox.desktop;
kwriteconfig6 --file mimeapps.list --group "Default Applications" --key x-scheme-handler/http firefox_firefox.desktop;
kwriteconfig6 --file mimeapps.list --group "Default Applications" --key x-scheme-handler/https firefox_firefox.desktop;
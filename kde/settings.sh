#!/bin/bash

# NOTE: Use `kcmshell5 --list` to see available modules, some other useful commands:
# `kreadconfig5 --file <file_name> --group <group_name> --key <key_name>`
# `kwriteconfig5 --file <file_name> --group <group_name> --key <key_name> <value>`

# ===== Appearance =====

# Theme: Breeze Dark
kwriteconfig5 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop

# Resolution Scale
kwriteconfig5 --file kwinrc --group Xwayland --key Scale 1.75

# Apply wallpaper
WALLPAPER_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wallpapers/astronaut-jellyfish-monokai.jpg"
if [[ -f "$WALLPAPER_SOURCE" ]]; then
    # Convert to absolute path
    WALLPAPER_SOURCE="$(readlink -f "$WALLPAPER_SOURCE")"
    
    # For lock screen, copy wallpaper to system directory to ensure accessibility
    # Lock screen needs the wallpaper in a location accessible even when user session isn't active
    SYSTEM_WALLPAPER_DIR="/usr/share/backgrounds"
    SYSTEM_WALLPAPER_PATH="$SYSTEM_WALLPAPER_DIR/astronaut-jellyfish-monokai.jpg"
    
    # Copy wallpaper to system directory if it doesn't exist or is different
    if [[ ! -f "$SYSTEM_WALLPAPER_PATH" ]] || ! cmp -s "$WALLPAPER_SOURCE" "$SYSTEM_WALLPAPER_PATH" 2>/dev/null; then
        echo "Copying wallpaper to system directory for lock screen access..."
        sudo mkdir -p "$SYSTEM_WALLPAPER_DIR"
        sudo cp "$WALLPAPER_SOURCE" "$SYSTEM_WALLPAPER_PATH"
        sudo chmod 644 "$SYSTEM_WALLPAPER_PATH"
    fi
    
    # Use system path for lock screen, original path for desktop
    DESKTOP_WALLPAPER_PATH="$WALLPAPER_SOURCE"
    LOCKSCREEN_WALLPAPER_PATH="$SYSTEM_WALLPAPER_PATH"
    
    # Set desktop wallpaper using plasma-apply-wallpaperimage
    # This applies to all desktops/screens automatically
    if command -v plasma-apply-wallpaperimage &> /dev/null; then
        plasma-apply-wallpaperimage "$DESKTOP_WALLPAPER_PATH"
    fi
    
    # Also configure via qdbus for all desktops to ensure persistence
    # This ensures the setting persists even if plasma-apply-wallpaperimage doesn't fully apply
    # The qdbus method sets wallpaper for all desktops/screens programmatically
    if command -v qdbus &> /dev/null && qdbus org.kde.plasmashell /PlasmaShell &>/dev/null; then
        # Use qdbus to set wallpaper for all desktops
        # This method ensures all desktops get the wallpaper set and persists across sessions
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var allDesktops = desktops();
        for (var i = 0; i < allDesktops.length; i++) {
            var desktop = allDesktops[i];
            desktop.wallpaperPlugin = 'org.kde.image';
            desktop.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
            desktop.writeConfig('Image', 'file://$DESKTOP_WALLPAPER_PATH');
        }
        " 2>/dev/null || true
    fi
    
    # Configure lock screen wallpaper
    # The wallpaper plugin is determined by the group structure (org.kde.image)
    # Set the wallpaper image path (using system path for accessibility)
    kwriteconfig5 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$LOCKSCREEN_WALLPAPER_PATH"
    
    # Set fill mode (2 = Scaled, 1 = Centered, 0 = Tiled)
    kwriteconfig5 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key FillMode 2
    
    # Clear any theme wallpaper override that might be causing the default to show
    # Setting Theme name to empty ensures custom wallpaper is used
    kwriteconfig5 --file kscreenlockerrc --group Greeter --group Theme --key name ""
    
    # Configure SDDM login screen wallpaper
    # SDDM login screen requires the wallpaper to be configured in the theme's configuration file
    # First, try to detect the active SDDM theme
    SDDM_THEME=""
    if [[ -f /etc/sddm.conf ]]; then
        # Try to read theme from /etc/sddm.conf
        SDDM_THEME=$(grep -E "^Current=" /etc/sddm.conf 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || true)
    fi
    
    # If not found, check user config
    if [[ -z "$SDDM_THEME" ]] && [[ -f ~/.config/sddm/sddm.conf ]]; then
        SDDM_THEME=$(grep -E "^Current=" ~/.config/sddm/sddm.conf 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || true)
    fi
    
    # Default to breeze if no theme found
    if [[ -z "$SDDM_THEME" ]]; then
        SDDM_THEME="breeze"
    fi
    
    # Configure the SDDM theme's wallpaper
    SDDM_THEME_DIR="/usr/share/sddm/themes/$SDDM_THEME"
    SDDM_THEME_CONF_USER="$SDDM_THEME_DIR/theme.conf.user"
    
    if [[ -d "$SDDM_THEME_DIR" ]]; then
        echo "Configuring SDDM login screen wallpaper for theme: $SDDM_THEME"
        # Create theme.conf.user with the background setting
        # This file overrides the default theme.conf settings
        sudo tee "$SDDM_THEME_CONF_USER" > /dev/null <<EOF
[General]
background=$LOCKSCREEN_WALLPAPER_PATH
EOF
        sudo chmod 644 "$SDDM_THEME_CONF_USER"
        echo "SDDM login screen wallpaper configured"
    else
        echo "Warning: SDDM theme directory not found: $SDDM_THEME_DIR"
        echo "Trying common theme locations..."
        # Try common themes
        for theme in breeze breeze-dark; do
            if [[ -d "/usr/share/sddm/themes/$theme" ]]; then
                echo "Found theme: $theme, configuring..."
                sudo tee "/usr/share/sddm/themes/$theme/theme.conf.user" > /dev/null <<EOF
[General]
background=$LOCKSCREEN_WALLPAPER_PATH
EOF
                sudo chmod 644 "/usr/share/sddm/themes/$theme/theme.conf.user"
                echo "SDDM login screen wallpaper configured for theme: $theme"
                break
            fi
        done
    fi
    
    echo "Wallpaper configured for desktop, lock screen, and login screen"
else
    echo "Warning: Wallpaper file not found at $WALLPAPER_SOURCE"
fi

# ===== Behavior =====

# On login, always start with an empty session
kwriteconfig5 --file ksmserverrc --group General --key loginMode emptySession

# Number of Virtual Desktops
kwriteconfig5 --file kwinrc --group Desktops --key Number 4


# ===== Default Applications =====

# Kitty
kwriteconfig5 --file kdeglobals --group General --key TerminalApplication ~/.local/kitty.app/bin/kitty
kwriteconfig5 --file kdeglobals --group General --key TerminalService kitty.desktop

# Firefox
kwriteconfig5 --file kdeglobals --group General --key BrowserApplication firefox_firefox.desktop
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key application/pdf firefox_firefox.desktop;
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key text/html firefox_firefox.desktop;
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key x-scheme-handler/http firefox_firefox.desktop;
kwriteconfig5 --file mimeapps.list --group "Default Applications" --key x-scheme-handler/https firefox_firefox.desktop;

#!/bin/bash

# Wallpaper configuration for KDE Plasma
# Sets wallpaper for desktop, lock screen, and login screen (SDDM)

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
    # This is a known issue area - multiple approaches may be needed
    
    # First, try to detect the active SDDM theme
    SDDM_THEME=""
    if [[ -f /etc/sddm.conf ]]; then
        # Try to read theme from /etc/sddm.conf
        SDDM_THEME=$(grep -E "^Current=" /etc/sddm.conf 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || true)
    fi
    
    # Also check /etc/sddm.conf.d/ for additional config files
    if [[ -z "$SDDM_THEME" ]] && [[ -d /etc/sddm.conf.d ]]; then
        for conf_file in /etc/sddm.conf.d/*.conf; do
            [[ -f "$conf_file" ]] || continue
            SDDM_THEME=$(grep -E "^Current=" "$conf_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || true)
            [[ -n "$SDDM_THEME" ]] && break
        done
    fi
    
    # If not found, check user config
    if [[ -z "$SDDM_THEME" ]] && [[ -f ~/.config/sddm/sddm.conf ]]; then
        SDDM_THEME=$(grep -E "^Current=" ~/.config/sddm/sddm.conf 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || true)
    fi
    
    # Default to breeze if no theme found
    if [[ -z "$SDDM_THEME" ]]; then
        SDDM_THEME="breeze"
    fi
    
    echo "Detected SDDM theme: $SDDM_THEME"
    
    # Configure the SDDM theme's wallpaper
    SDDM_THEME_DIR="/usr/share/sddm/themes/$SDDM_THEME"
    SDDM_THEME_CONF_USER="$SDDM_THEME_DIR/theme.conf.user"
    SDDM_THEME_CONF="$SDDM_THEME_DIR/theme.conf"
    SDDM_CONFIGURED=false
    
    # Check if /usr is writable (some systems have immutable /usr)
    if [[ -d "$SDDM_THEME_DIR" ]]; then
        # Try theme.conf.user first (user override, preferred method)
        if sudo touch "$SDDM_THEME_CONF_USER" 2>/dev/null; then
            echo "Configuring SDDM login screen wallpaper via theme.conf.user..."
            sudo tee "$SDDM_THEME_CONF_USER" > /dev/null <<EOF
[General]
background=$LOCKSCREEN_WALLPAPER_PATH
EOF
            sudo chmod 644 "$SDDM_THEME_CONF_USER"
            SDDM_CONFIGURED=true
        # If theme.conf.user fails, try editing theme.conf directly
        elif [[ -f "$SDDM_THEME_CONF" ]] && sudo test -w "$SDDM_THEME_CONF" 2>/dev/null; then
            echo "theme.conf.user not writable, editing theme.conf directly..."
            # Backup original theme.conf
            if [[ ! -f "${SDDM_THEME_CONF}.bak" ]]; then
                sudo cp "$SDDM_THEME_CONF" "${SDDM_THEME_CONF}.bak"
            fi
            # Update or add background setting in theme.conf
            if grep -q "^background=" "$SDDM_THEME_CONF" 2>/dev/null; then
                # Replace existing background line
                sudo sed -i "s|^background=.*|background=$LOCKSCREEN_WALLPAPER_PATH|" "$SDDM_THEME_CONF"
            else
                # Add background setting to [General] section
                if grep -q "^\[General\]" "$SDDM_THEME_CONF" 2>/dev/null; then
                    sudo sed -i "/^\[General\]/a background=$LOCKSCREEN_WALLPAPER_PATH" "$SDDM_THEME_CONF"
                else
                    # Add [General] section and background
                    echo "" | sudo tee -a "$SDDM_THEME_CONF" > /dev/null
                    echo "[General]" | sudo tee -a "$SDDM_THEME_CONF" > /dev/null
                    echo "background=$LOCKSCREEN_WALLPAPER_PATH" | sudo tee -a "$SDDM_THEME_CONF" > /dev/null
                fi
            fi
            SDDM_CONFIGURED=true
        fi
        
        if [[ "$SDDM_CONFIGURED" == true ]]; then
            echo "SDDM login screen wallpaper configured for theme: $SDDM_THEME"
            # Restart SDDM service to apply changes (if systemd is available and we're not in a session)
            if command -v systemctl &> /dev/null && ! systemctl is-active --quiet sddm 2>/dev/null; then
                echo "SDDM service is not running (normal if configuring before first login)"
            elif command -v systemctl &> /dev/null; then
                echo "Note: You may need to restart SDDM or reboot to see login screen changes"
                echo "      Run: sudo systemctl restart sddm"
            fi
        else
            echo "Warning: Could not write to SDDM theme configuration files"
            echo "         Theme directory may be read-only (immutable filesystem)"
        fi
    else
        echo "Warning: SDDM theme directory not found: $SDDM_THEME_DIR"
        echo "Trying common theme locations..."
        # Try common themes
        for theme in breeze breeze-dark; do
            if [[ -d "/usr/share/sddm/themes/$theme" ]]; then
                echo "Found theme: $theme, configuring..."
                if sudo tee "/usr/share/sddm/themes/$theme/theme.conf.user" > /dev/null <<EOF
[General]
background=$LOCKSCREEN_WALLPAPER_PATH
EOF
                then
                    sudo chmod 644 "/usr/share/sddm/themes/$theme/theme.conf.user"
                    echo "SDDM login screen wallpaper configured for theme: $theme"
                    SDDM_CONFIGURED=true
                    break
                fi
            fi
        done
    fi
    
    echo "Wallpaper configured for desktop, lock screen, and login screen"
else
    echo "Warning: Wallpaper file not found at $WALLPAPER_SOURCE"
fi


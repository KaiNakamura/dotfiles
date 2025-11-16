#!/bin/bash
# apply-kksrc.sh - Convert and apply binds.kksrc programmatically

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDS_FILE="$WORKDIR/binds.kksrc"
TARGET_FILE="$HOME/.config/kglobalshortcutsrc"

# Check if binds.kksrc exists
if [[ ! -f "$BINDS_FILE" ]]; then
    echo "Error: binds.kksrc not found at $BINDS_FILE"
    exit 1
fi

# Backup existing config
if [[ -f "$TARGET_FILE" ]]; then
    echo "Backing up existing shortcuts..."
    cp "$TARGET_FILE" "${TARGET_FILE}.backup"
fi

echo "Applying shortcuts from binds.kksrc..."

# Read binds.kksrc and collect all shortcuts we'll be setting
declare -A shortcuts_to_set
declare -a kwin_actions
declare -a kwin_values

in_kwin_section=false
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    
    if [[ "$line" =~ ^\[.*\] ]]; then
        [[ "$line" =~ \[kwin\] ]] && in_kwin_section=true || in_kwin_section=false
        continue
    fi
    
    [[ "$in_kwin_section" == false ]] && continue
    
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
        action="${BASH_REMATCH[1]}"
        keybindings="${BASH_REMATCH[2]}"
        action=$(echo "$action" | xargs)
        keybindings=$(echo "$keybindings" | xargs)
        [[ -z "$keybindings" ]] && continue
        
        # Process bindings
        IFS=';' read -ra BINDINGS <<< "$keybindings"
        bindings_array=()
        for binding in "${BINDINGS[@]}"; do
            binding=$(echo "$binding" | xargs)
            [[ -n "$binding" && ! "$binding" =~ ^Launch\ \( ]] && bindings_array+=("$binding")
        done
        [[ ${#bindings_array[@]} -eq 0 ]] && continue
        
        # Store shortcuts for conflict detection
        for binding in "${bindings_array[@]}"; do
            normalized=$(echo "$binding" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
            shortcuts_to_set["$normalized"]=1
        done
        
        # Build value string
        first_binding="${bindings_array[0]}"
        bindings_str=""
        for binding in "${bindings_array[@]}"; do
            [[ -n "$bindings_str" ]] && bindings_str+=$'\t'
            bindings_str+="$binding"
        done
        value="${bindings_str},${first_binding},${action}"
        
        kwin_actions+=("$action")
        kwin_values+=("$value")
    fi
done < "$BINDS_FILE"

# Read kglobalshortcutsrc and find all conflicts
declare -a conflicts_to_unbind

if [[ -f "$TARGET_FILE" ]]; then
    current_section=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        
        [[ -z "$current_section" ]] && continue
        [[ "$current_section" == "kwin" ]] && continue
        
        if [[ "$line" =~ ^([^=]+)=([^,]+), ]]; then
            action="${BASH_REMATCH[1]}"
            existing_bindings="${BASH_REMATCH[2]}"
            
            # Check all bindings (they can be tab-separated, stored as literal \t or actual tab)
            # First, replace literal \t with actual tab for consistent processing
            # Use printf to interpret escape sequences
            existing_bindings=$(printf "%b" "$existing_bindings")
            
            # Split by tab and check each binding
            IFS=$'\t' read -ra BINDING_ARRAY <<< "$existing_bindings"
            for existing_binding in "${BINDING_ARRAY[@]}"; do
                # Trim whitespace
                existing_binding=$(echo "$existing_binding" | xargs)
                [[ -z "$existing_binding" ]] && continue
                
                normalized_existing=$(echo "$existing_binding" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
                
                if [[ -n "${shortcuts_to_set[$normalized_existing]}" ]]; then
                    conflicts_to_unbind+=("$current_section|$action")
                    echo "Unbinding conflicting shortcut: [$current_section] $action = $existing_binding"
                    break  # Only need to add once per action
                fi
            done
        fi
    done < "$TARGET_FILE"
fi

# Unbind all conflicts
unbinds_count=0
for conflict in "${conflicts_to_unbind[@]}"; do
    IFS='|' read -r section action <<< "$conflict"
    if kwriteconfig5 --file kglobalshortcutsrc --group "$section" --key "$action" "none" 2>/dev/null; then
        ((unbinds_count++))
    fi
done

# Apply all KWin shortcuts
shortcuts_applied=0
for i in "${!kwin_actions[@]}"; do
    if kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "${kwin_actions[$i]}" "${kwin_values[$i]}" 2>/dev/null; then
        ((shortcuts_applied++))
    fi
done

echo "Unbound $unbinds_count conflicting shortcuts."
echo "Applied $shortcuts_applied shortcuts."

# Reload shortcuts by restarting kglobalaccel service
echo "Reloading kglobalaccel service..."

if systemctl --user restart plasma-kglobalaccel.service; then
    sleep 1
    echo "Shortcuts reloaded successfully."
    echo "Note: You may need to log out and back in for all shortcuts to take full effect."
else
    echo "Error: Failed to restart plasma-kglobalaccel.service"
    echo "Changes have been saved to ~/.config/kglobalshortcutsrc"
    echo "Please log out and back in, or restart KDE for changes to take effect."
    exit 1
fi

echo "Done! Shortcuts applied."

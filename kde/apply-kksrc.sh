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

# Track if we're in the kwin section
in_kwin_section=false
shortcuts_applied=0

# Parse binds.kksrc and apply using kwriteconfig5
while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Check for section header
    if [[ "$line" =~ ^\[.*\] ]]; then
        if [[ "$line" =~ \[kwin\] ]]; then
            in_kwin_section=true
        else
            in_kwin_section=false
        fi
        continue
    fi
    
    # Only process lines in kwin section
    [[ "$in_kwin_section" == false ]] && continue
    
    # Parse action and keybindings
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
        action="${BASH_REMATCH[1]}"
        keybindings="${BASH_REMATCH[2]}"
        
        # Trim whitespace
        action=$(echo "$action" | xargs)
        keybindings=$(echo "$keybindings" | xargs)
        
        # Skip actions with no bindings
        [[ -z "$keybindings" ]] && continue
        
        # Convert semicolon-separated bindings to tab-separated
        # Format for kwriteconfig5: "BIND1<TAB>BIND2,DEFAULT,DESCRIPTION"
        # Use first binding as DEFAULT, action name as DESCRIPTION
        IFS=';' read -ra BINDINGS <<< "$keybindings"
        
        # Build tab-separated bindings string (filter out empty/invalid entries)
        bindings_array=()
        for binding in "${BINDINGS[@]}"; do
            binding=$(echo "$binding" | xargs)
            # Skip empty bindings or ones that look invalid (contain parentheses without valid key names)
            if [[ -n "$binding" && ! "$binding" =~ ^Launch\ \( ]]; then
                bindings_array+=("$binding")
            fi
        done
        
        # Skip if no valid bindings found
        [[ ${#bindings_array[@]} -eq 0 ]] && continue
        
        # First binding is used as default
        first_binding="${bindings_array[0]}"
        
        # Build tab-separated bindings string
        bindings_str=""
        for binding in "${bindings_array[@]}"; do
            if [[ -n "$bindings_str" ]]; then
                bindings_str+=$'\t'
            fi
            bindings_str+="$binding"
        done
        
        # Format: "BIND1<TAB>BIND2,DEFAULT,DESCRIPTION"
        value="${bindings_str},${first_binding},${action}"
        
        # Apply using kwriteconfig5
        if kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "$action" "$value" 2>/dev/null; then
            ((shortcuts_applied++))
        else
            echo "Warning: Failed to apply shortcut for '$action'" >&2
        fi
    fi
done < "$BINDS_FILE"

echo "Applied $shortcuts_applied shortcuts."

echo "Reloading KWin shortcuts..."

# Reload shortcuts - try multiple methods for compatibility
if qdbus org.kde.kglobalaccel /component/kwin reconfigure 2>/dev/null; then
    echo "Shortcuts reloaded successfully."
elif qdbus org.kde.KWin /KWin reconfigure 2>/dev/null; then
    echo "Shortcuts reloaded successfully."
else
    echo "Note: Could not reload shortcuts automatically."
    echo "Please log out and back in, or restart KDE for changes to take effect."
fi

echo "Done! Shortcuts applied."


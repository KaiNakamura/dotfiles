#!/bin/bash
# apply-kksrc.sh - Convert and apply binds.kksrc programmatically
# TODO: Verify python3 + python-dbus are available on a fresh KDE install.
#       The D-Bus live-activation step (and kde/install.sh HJKL setup) depend on them.
#       If missing, shortcuts still persist via kwriteconfig but won't activate until re-login.

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

# Detect kwriteconfig version
if command -v kwriteconfig6 &> /dev/null; then
    KWRITECONFIG=kwriteconfig6
elif command -v kwriteconfig5 &> /dev/null; then
    KWRITECONFIG=kwriteconfig5
else
    echo "Error: Neither kwriteconfig5 nor kwriteconfig6 found."
    exit 1
fi

echo "Applying shortcuts from binds.kksrc..."

# Read binds.kksrc and collect all shortcuts we'll be setting
declare -A shortcuts_to_set
declare -A managed_sections
declare -a entry_groups
declare -a entry_actions
declare -a entry_values

current_group=""
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
        current_group="${BASH_REMATCH[1]}"
        managed_sections["$current_group"]=1
        continue
    fi

    [[ -z "$current_group" ]] && continue

    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
        action="${BASH_REMATCH[1]}"
        keybindings="${BASH_REMATCH[2]}"
        action=$(echo "$action" | xargs)
        keybindings=$(echo "$keybindings" | xargs)
        # If keybindings is empty, unbind the action
        if [[ -z "$keybindings" ]]; then
            entry_groups+=("$current_group")
            entry_actions+=("$action")
            entry_values+=("none")
            continue
        fi

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

        entry_groups+=("$current_group")
        entry_actions+=("$action")
        entry_values+=("$value")
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
        # Skip sections we're managing (we'll overwrite them)
        [[ -n "${managed_sections[$current_section]}" ]] && continue

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
    if $KWRITECONFIG --file kglobalshortcutsrc --group "$section" --key "$action" "none" 2>/dev/null; then
        ((unbinds_count++))
    fi
done

# Apply all shortcuts
shortcuts_applied=0
for i in "${!entry_actions[@]}"; do
    if [[ "${entry_values[$i]}" == "none" ]]; then
        if $KWRITECONFIG --file kglobalshortcutsrc --group "${entry_groups[$i]}" --key "${entry_actions[$i]}" "none" 2>/dev/null; then
            ((shortcuts_applied++))
        fi
    else
        if $KWRITECONFIG --file kglobalshortcutsrc --group "${entry_groups[$i]}" --key "${entry_actions[$i]}" "${entry_values[$i]}" 2>/dev/null; then
            ((shortcuts_applied++))
        fi
    fi
done

echo "Unbound $unbinds_count conflicting shortcuts."
echo "Applied $shortcuts_applied shortcuts."

# Live-activate shortcuts via D-Bus
# The kglobalaccel daemon reads kglobalshortcutsrc only once at startup and never
# re-reads it. On Wayland, it's embedded in kwin_wayland so it can't be restarted
# independently. The only way to activate shortcuts without re-login is via the
# setForeignShortcut D-Bus method, which updates the daemon's in-memory state.
echo "Activating shortcuts via D-Bus..."

/usr/bin/python3 -c "
import sys

try:
    import dbus
except ImportError:
    print('  python-dbus not available, skipping live activation')
    print('  Changes saved to ~/.config/kglobalshortcutsrc')
    print('  You may need to log out and back in for shortcuts to take effect.')
    sys.exit(0)

MODIFIERS = {
    'Meta': 0x10000000,
    'Ctrl': 0x04000000,
    'Shift': 0x02000000,
    'Alt': 0x08000000,
}

KEY_MAP = {}
for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
    KEY_MAP[c] = ord(c)
for c in '0123456789':
    KEY_MAP[c] = ord(c)
for i in range(1, 25):
    KEY_MAP[f'F{i}'] = 0x01000030 + (i - 1)
KEY_MAP.update({
    'Up': 0x01000013, 'Down': 0x01000015,
    'Left': 0x01000012, 'Right': 0x01000014,
    'Esc': 0x01000000, 'Tab': 0x01000001,
    'Return': 0x01000004, 'Enter': 0x01000004,
    'Del': 0x01000007, 'Delete': 0x01000007,
    'Print': 0x01000009, 'Space': 0x20,
    '!': 0x21, '@': 0x40, '#': 0x23, '\$': 0x24,
    '%': 0x25, '^': 0x5e, '&': 0x26, '*': 0x2a,
    '(': 0x28, ')': 0x29, '+': 0x2b, '-': 0x2d,
    '=': 0x3d, '\`': 0x60, '~': 0x7e,
})

COMPONENT_FRIENDLY = {
    'kwin': 'KWin',
    'ksmserver': 'Session Management',
    'org.kde.spectacle.desktop': 'Spectacle',
    'firefox.desktop': 'Firefox',
    'kitty.desktop': 'Kitty',
}

def parse_key_combo(combo_str):
    combo = combo_str.strip()
    if not combo:
        return None
    code = 0
    # Loop until no more modifiers are consumed (handles any modifier order)
    changed = True
    while changed:
        changed = False
        for mod_name, mod_code in MODIFIERS.items():
            prefix = mod_name + '+'
            if combo.startswith(prefix):
                code |= mod_code
                combo = combo[len(prefix):]
                changed = True
    if combo in KEY_MAP:
        code |= KEY_MAP[combo]
        return code
    return None

# Parse binds.kksrc
entries = []
managed_components = set()
current_component = None
with open('$BINDS_FILE') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('['):
            idx = line.index(']')
            current_component = line[1:idx]
            managed_components.add(current_component)
            continue
        if current_component and '=' in line:
            key, _, value = line.partition('=')
            action = key.strip()
            bindings_str = value.strip()
            if not bindings_str:
                continue
            bindings = [b.strip() for b in bindings_str.split(';')]
            key_codes = []
            for b in bindings:
                if not b:
                    continue
                code = parse_key_combo(b)
                if code is not None:
                    key_codes.append(code)
                else:
                    print(f'  Skipping unknown key: {b}')
            if key_codes:
                entries.append((current_component, action, key_codes))

# Collect all key codes we want to claim
desired_keys = set()
for _, _, key_codes in entries:
    desired_keys.update(key_codes)

# Connect to D-Bus
try:
    bus = dbus.SessionBus()
    proxy = bus.get_object('org.kde.kglobalaccel', '/kglobalaccel')
    iface = dbus.Interface(proxy, 'org.kde.KGlobalAccel')
except dbus.exceptions.DBusException as e:
    print(f'  Could not connect to kglobalaccel D-Bus: {e}')
    print('  Changes saved to ~/.config/kglobalshortcutsrc')
    print('  You may need to log out and back in for shortcuts to take effect.')
    sys.exit(0)

# Unbind conflicting shortcuts from other components in the daemon's memory
# (kwriteconfig only updates the config file, not the running daemon)
unbound = 0
try:
    components = iface.allMainComponents()
    for comp_info in components:
        comp_name = str(comp_info[0])
        if comp_name in managed_components:
            continue
        try:
            comp_path = iface.getComponent(comp_name)
            comp_proxy = bus.get_object('org.kde.kglobalaccel', comp_path)
            comp_iface = dbus.Interface(comp_proxy, 'org.kde.kglobalaccel.Component')
            for info in comp_iface.allShortcutInfos():
                # info: [0]=actionUnique [1]=actionFriendly [2]=compUnique
                #        [3]=compFriendly [4]=context [5]=contextFriendly
                #        [6]=current keys (ai) [7]=default keys (ai)
                action_name = str(info[0])
                current_keys = info[6]
                if not current_keys:
                    continue
                for key_val in current_keys:
                    if int(key_val) in desired_keys:
                        comp_friendly = str(info[3])
                        action_id = dbus.Array([comp_name, action_name, comp_friendly, action_name], signature='s')
                        iface.setForeignShortcut(action_id, dbus.Array([dbus.Int32(0)], signature='i'))
                        print(f'  Unbound conflict: [{comp_name}] {action_name}')
                        unbound += 1
                        break
        except dbus.exceptions.DBusException:
            pass
except dbus.exceptions.DBusException as e:
    print(f'  Warning: Could not scan for conflicts: {e}')

# Set all shortcuts
activated = 0
for component, action, key_codes in entries:
    friendly = COMPONENT_FRIENDLY.get(component, component)
    action_id = dbus.Array([component, action, friendly, action], signature='s')
    keys = dbus.Array([dbus.Int32(k) for k in key_codes], signature='i')
    try:
        iface.setForeignShortcut(action_id, keys)
        activated += 1
    except dbus.exceptions.DBusException as e:
        print(f'  Failed: [{component}] {action}: {e}')

if unbound:
    print(f'  Unbound {unbound} conflicting shortcuts from daemon.')
print(f'  Live-activated {activated} shortcuts via D-Bus.')
"

echo "Done! Shortcuts applied."

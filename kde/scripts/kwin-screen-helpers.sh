#!/bin/bash
# kwin-screen-helpers.sh - Shared helper functions for screen manipulation

# Global associative array for screen geometries
declare -gA SCREEN_GEOMETRIES

# Get current active screen name
get_current_screen() {
    qdbus org.kde.KWin /KWin activeOutputName 2>/dev/null
}

# Parse all screen geometries from kscreen-doctor output
parse_all_screen_geometries() {
    # Clear existing geometries (in case function is called multiple times)
    SCREEN_GEOMETRIES=()
    
    # Strip ANSI color codes from kscreen-doctor output and parse
    while IFS= read -r line; do
        # Remove ANSI color codes (escape sequences like [01;32m)
        line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
        
        # Extract screen name first
        if [[ $line =~ Output:[[:space:]]+[0-9]+[[:space:]]+([^[:space:]]+) ]]; then
            screen_name="${BASH_REMATCH[1]}"
            # Then extract geometry (BASH_REMATCH will be overwritten, so we saved screen_name)
            if [[ $line =~ Geometry:[[:space:]]+([0-9]+),([0-9]+)[[:space:]]+([0-9]+)x([0-9]+) ]]; then
                x="${BASH_REMATCH[1]}"
                y="${BASH_REMATCH[2]}"
                width="${BASH_REMATCH[3]}"
                height="${BASH_REMATCH[4]}"
                SCREEN_GEOMETRIES["$screen_name"]="$x $y $width $height"
            fi
        fi
    done < <(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
}

# Get geometry for a specific screen name
get_screen_geometry() {
    local screen_name=$1
    echo "${SCREEN_GEOMETRIES[$screen_name]}"
}

# Find neighbor screen in given direction, or return empty if none exists
find_neighbor_screen() {
    local current_screen=$1
    local direction=$2
    
    # Get current screen geometry
    local current_geom=$(get_screen_geometry "$current_screen")
    if [[ -z "$current_geom" ]]; then
        return 1
    fi
    
    read -r current_x current_y current_width current_height <<< "$current_geom"
    
    local best_screen=""
    local best_distance=-1
    local best_has_overlap=false
    
    # Iterate through all screens
    for screen_name in "${!SCREEN_GEOMETRIES[@]}"; do
        [[ "$screen_name" == "$current_screen" ]] && continue
        
        local geom="${SCREEN_GEOMETRIES[$screen_name]}"
        read -r x y width height <<< "$geom"
        
        case "$direction" in
            left)
                if [[ $x -lt $current_x ]]; then
                    # Screen is to the left
                    # Check if screens overlap vertically (prefer aligned screens)
                    current_y_end=$((current_y + current_height))
                    y_end=$((y + height))
                    # Calculate vertical overlap
                    overlap_start=$((current_y > y ? current_y : y))
                    overlap_end=$((current_y_end < y_end ? current_y_end : y_end))
                    vertical_overlap=$((overlap_end - overlap_start))
                    has_overlap=false
                    [[ $vertical_overlap -gt 0 ]] && has_overlap=true
                    
                    distance=$((current_x - x))
                    
                    # Prefer screens with overlap over those without
                    if [[ "$has_overlap" == "true" ]]; then
                        if [[ "$best_has_overlap" != "true" ]] || [[ $distance -lt $best_distance ]]; then
                            best_screen="$screen_name"
                            best_distance=$distance
                            best_has_overlap=true
                        fi
                    elif [[ "$best_has_overlap" != "true" ]] && [[ $best_distance -lt 0 || $distance -lt $best_distance ]]; then
                        # Only consider non-overlapping if no overlapping screen found yet
                        best_screen="$screen_name"
                        best_distance=$distance
                        best_has_overlap=false
                    fi
                fi
                ;;
            right)
                if [[ $x -gt $current_x ]]; then
                    # Screen is to the right
                    current_y_end=$((current_y + current_height))
                    y_end=$((y + height))
                    overlap_start=$((current_y > y ? current_y : y))
                    overlap_end=$((current_y_end < y_end ? current_y_end : y_end))
                    vertical_overlap=$((overlap_end - overlap_start))
                    has_overlap=false
                    [[ $vertical_overlap -gt 0 ]] && has_overlap=true
                    
                    distance=$((x - current_x))
                    
                    if [[ "$has_overlap" == "true" ]]; then
                        if [[ "$best_has_overlap" != "true" ]] || [[ $distance -lt $best_distance ]]; then
                            best_screen="$screen_name"
                            best_distance=$distance
                            best_has_overlap=true
                        fi
                    elif [[ "$best_has_overlap" != "true" ]] && [[ $best_distance -lt 0 || $distance -lt $best_distance ]]; then
                        best_screen="$screen_name"
                        best_distance=$distance
                        best_has_overlap=false
                    fi
                fi
                ;;
            up)
                if [[ $y -lt $current_y ]]; then
                    # Screen is above
                    current_x_end=$((current_x + current_width))
                    x_end=$((x + width))
                    overlap_start=$((current_x > x ? current_x : x))
                    overlap_end=$((current_x_end < x_end ? current_x_end : x_end))
                    horizontal_overlap=$((overlap_end - overlap_start))
                    has_overlap=false
                    [[ $horizontal_overlap -gt 0 ]] && has_overlap=true
                    
                    distance=$((current_y - y))
                    
                    if [[ "$has_overlap" == "true" ]]; then
                        if [[ "$best_has_overlap" != "true" ]] || [[ $distance -lt $best_distance ]]; then
                            best_screen="$screen_name"
                            best_distance=$distance
                            best_has_overlap=true
                        fi
                    elif [[ "$best_has_overlap" != "true" ]] && [[ $best_distance -lt 0 || $distance -lt $best_distance ]]; then
                        best_screen="$screen_name"
                        best_distance=$distance
                        best_has_overlap=false
                    fi
                fi
                ;;
            down)
                if [[ $y -gt $current_y ]]; then
                    # Screen is below
                    current_x_end=$((current_x + current_width))
                    x_end=$((x + width))
                    overlap_start=$((current_x > x ? current_x : x))
                    overlap_end=$((current_x_end < x_end ? current_x_end : x_end))
                    horizontal_overlap=$((overlap_end - overlap_start))
                    has_overlap=false
                    [[ $horizontal_overlap -gt 0 ]] && has_overlap=true
                    
                    distance=$((y - current_y))
                    
                    if [[ "$has_overlap" == "true" ]]; then
                        if [[ "$best_has_overlap" != "true" ]] || [[ $distance -lt $best_distance ]]; then
                            best_screen="$screen_name"
                            best_distance=$distance
                            best_has_overlap=true
                        fi
                    elif [[ "$best_has_overlap" != "true" ]] && [[ $best_distance -lt 0 || $distance -lt $best_distance ]]; then
                        best_screen="$screen_name"
                        best_distance=$distance
                        best_has_overlap=false
                    fi
                fi
                ;;
        esac
    done
    
    echo "$best_screen"
}

# Move cursor to target coordinates using ydotool workaround
# Workaround for ydotool absolute coordinate bug (see iteration-08):
# 1. Move to (0,0) using absolute (this works - goes to top-left)
# 2. Move relatively from (0,0) to target coordinates
move_cursor_to_coordinates() {
    local target_x=$1
    local target_y=$2
    
    export YDOTOOL_SOCKET=/tmp/.ydotool_socket
    
    # Step 1: Move to origin (0,0) using absolute
    ydotool mousemove --absolute -x 0 -y 0 2>/dev/null
    sleep 0.05  # Small delay to ensure movement completes
    
    # Step 2: Move relatively from (0,0) to target
    ydotool mousemove -x "$target_x" -y "$target_y" 2>/dev/null
}


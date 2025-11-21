#!/bin/bash
# kwin-center-cursor.sh - Helper to center cursor on active window

# Wait a moment for focus/position to settle
sleep 0.1

# Get active window and move cursor to center
WINDOW_ID=$(xdotool getactivewindow 2>/dev/null)
if [[ -n "$WINDOW_ID" && "$WINDOW_ID" != "0" ]]; then
    eval $(xdotool getwindowgeometry --shell $WINDOW_ID 2>/dev/null)
    if [[ -n "$X" && -n "$Y" && -n "$WIDTH" && -n "$HEIGHT" ]]; then
        CENTER_X=$((X + WIDTH / 2))
        CENTER_Y=$((Y + HEIGHT / 2))
        xdotool mousemove $CENTER_X $CENTER_Y 2>/dev/null
    fi
fi


#!/usr/bin/env bash
# Run while Grok Bot is frozen after a paste. Read-only. Writes ~/grok-freeze-<time>.txt
out=~/grok-freeze-$(date +%H%M%S).txt
{
echo "== $(date)"
echo "== clipboard owner"; python3 $HOME/.local/share/clipwatch/selowner.py 2>/dev/null | head -3
W=$(python3 $HOME/.local/share/clipwatch/selowner.py 2>/dev/null | awk '/== CLIPBOARD /{print $3}'); [ -n "$W" ] && [ "$W" != 0x0 ] && P=$(python3 $HOME/.local/share/clipwatch/xrespid.py $W) && ps -o pid,args -p $P | cut -c1-200
echo "== does the owner answer?"; /usr/bin/time -f "TARGETS %es exit=%x" timeout 3 xclip -selection clipboard -o -t TARGETS 2>&1
echo "== last owner changes"; journalctl --user -u clipwatch --no-pager | tail -8
echo "== Grok Bot CPU over 3s (renderer ~100% = render hang; all ~0% = waiting on clipboard)"
top -b -d 3 -n 2 -p "$(pgrep -d, -f '/opt/Grok Bot/grok-bot')" | awk '/^top/{n++} n==2' | tail -n +7
} > "$out" 2>&1
echo "saved $out"

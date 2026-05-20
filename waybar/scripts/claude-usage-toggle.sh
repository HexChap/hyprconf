#!/bin/bash
STATE="$HOME/.cache/claude-usage-mode"
current=$(cat "$STATE" 2>/dev/null || echo "session")
if [ "$current" = "session" ]; then
    echo "weekly" > "$STATE"
else
    echo "session" > "$STATE"
fi
pkill -RTMIN+9 waybar

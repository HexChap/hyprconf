#!/bin/bash
# statusLine: caches rate_limits to ~/.cache/claude-usage.json for the waybar
# module. Outputs nothing — the HUD is on waybar instead.

CACHE="$HOME/.cache/claude-usage.json"

stdin_data=$(cat)

[ -z "$stdin_data" ] && exit 0

echo "$stdin_data" | python3 -c '
import json, sys
from datetime import datetime, timezone
cache = sys.argv[1]
try:
    data = json.load(sys.stdin)
    rl = data.get("rate_limits") or {}
    fh = rl.get("five_hour") or {}
    sd = rl.get("seven_day") or {}
    fh_pct = fh.get("used_percentage")
    sd_pct = sd.get("used_percentage")
    if fh_pct is not None or sd_pct is not None:
        snapshot = {
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "five_hour": {"used_percentage": fh_pct, "resets_at": fh.get("resets_at")},
            "seven_day": {"used_percentage": sd_pct, "resets_at": sd.get("resets_at")},
        }
        with open(cache, "w") as f:
            json.dump(snapshot, f)
except Exception:
    pass
' "$CACHE" 2>/dev/null

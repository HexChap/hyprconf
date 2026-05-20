#!/bin/bash
# statusLine wrapper: passes Claude Code's stdin through to claude-hud and
# caches rate_limits to ~/.cache/claude-usage.json for the waybar module.

cols=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
export COLUMNS=$(( ${cols:-120} > 4 ? ${cols:-120} - 4 : 1 ))

RUNTIME="/home/hexchap/.bun/bin/bun"
CACHE="$HOME/.cache/claude-usage.json"

plugin_dir=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null | \
    awk -F/ '{ print $(NF-1) "\t" $(0) }' | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' | \
    sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-)

stdin_data=$(cat)

if [ -n "$stdin_data" ]; then
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
fi

exec "$RUNTIME" --env-file /dev/null "${plugin_dir}src/index.ts" <<<"$stdin_data"

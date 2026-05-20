#!/usr/bin/env python3
"""Waybar module: Claude Code rate-limit usage in NERV style."""
import json
import os
from datetime import datetime, timezone

CACHE = os.path.expanduser("~/.cache/claude-usage.json")
STATE = os.path.expanduser("~/.cache/claude-usage-mode")
COLOR = "#fff4d2"


def span(text: str) -> str:
    return f"<span color='{COLOR}'>{text}</span>"


def fmt_duration(ts_unix: object) -> str | None:
    if not isinstance(ts_unix, (int, float)):
        return None
    secs = ts_unix - datetime.now(timezone.utc).timestamp()
    if secs <= 0:
        return "reset"
    days, rem = divmod(int(secs), 86400)
    hours, rem = divmod(rem, 3600)
    mins = rem // 60
    if days > 0:
        return f"{days}d {hours}h"
    if hours > 0:
        return f"{hours}h {mins}m"
    return f"{mins}m"


now = datetime.now(timezone.utc)

try:
    with open(CACHE) as f:
        data = json.load(f)

    updated_at = datetime.fromisoformat(data["updated_at"])
    if updated_at.tzinfo is None:
        updated_at = updated_at.replace(tzinfo=timezone.utc)
    age_s = (now - updated_at).total_seconds()

    fh = data.get("five_hour") or {}
    sd = data.get("seven_day") or {}
    fh_pct = fh.get("used_percentage")
    sd_pct = sd.get("used_percentage")
    fh_left = fmt_duration(fh.get("resets_at"))
    sd_left = fmt_duration(sd.get("resets_at"))

    try:
        with open(STATE) as f:
            mode = f.read().strip()
    except OSError:
        mode = "session"

    if mode == "weekly":
        label, pct, left = "週間", sd_pct, sd_left
    else:
        label, pct, left = "使用量", fh_pct, fh_left

    pct_str = span(f"{pct}%") if pct is not None else span("—")
    reset_str = f" ({left})" if left else ""
    text = f"{label}: {pct_str}{reset_str}"

    lines = ["Claude Code Usage", "━━━━━━━━━━━━━━━━━━━━"]
    if fh_pct is not None:
        lines.append(f"5h session : {fh_pct}%" + (f" (resets in {fh_left})" if fh_left else ""))
    if sd_pct is not None:
        lines.append(f"7-day      : {sd_pct}%" + (f" (resets in {sd_left})" if sd_left else ""))
    if age_s > 300:
        lines.append(f"⚠ data is {int(age_s // 60)}m old")
    lines.append("click to toggle 5h ⟷ weekly")

    print(json.dumps({
        "text": text,
        "tooltip": "\n".join(lines),
        "class": "claude-usage",
        "alt": mode,
    }))

except FileNotFoundError:
    print(json.dumps({
        "text": f"使用量: {span('—')}",
        "tooltip": "No data yet — start a Claude Code session",
        "class": "claude-usage-inactive",
    }))
except Exception as e:
    print(json.dumps({
        "text": "使用量: ?",
        "tooltip": f"Error: {e}",
        "class": "claude-usage-error",
    }))

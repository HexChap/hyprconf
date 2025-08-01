#!/bin/bash

# Icon for notification
NOTIF_ICON="$HOME/.config/swaync/images/ja.png"

# Path to the battery threshold file
THRESHOLD_FILE=$(find /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n 1)

if [[ ! -f "$THRESHOLD_FILE" ]]; then
    notify-send -e -u critical -i "$NOTIF_ICON" "Battery threshold file not found."
    exit 1
fi

# Read the current threshold
CURRENT=$(<"$THRESHOLD_FILE")

# Determine next value in cycle
case "$CURRENT" in
    60) NEXT=80 ;;
    80) NEXT=100 ;;
    100) NEXT=60 ;;
    *) NEXT=80 ;;  # default if unexpected value
esac

# Apply new threshold using sudo
echo "$NEXT" | sudo /usr/bin/tee "/sys/class/power_supply/BAT1/charge_control_end_threshold"

if [ $? -eq 0 ]; then
    # Notify user
    notify-send -e -u low "Battery threshold: $NEXT%"
else
    notify-send -e -u critical -i "$NOTIF_ICON" "Failed to set battery threshold."
fi

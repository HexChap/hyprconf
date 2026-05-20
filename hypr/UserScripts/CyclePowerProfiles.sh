#!/bin/bash

# Power Profile Cycler for power-profiles-daemon
# Cycles between: power-saver -> balanced -> performance -> power-saver

# Get current power profile
current=$(powerprofilesctl get)

case $current in
    "power-saver")
        powerprofilesctl set balanced
        notify-send "Switched to: balanced"
        ;;
    "balanced")
        powerprofilesctl set performance
        notify-send "Switched to: performance"
        ;;
    "performance")
        powerprofilesctl set power-saver
        echo "Switched to: power-saver"
        ;;
    *)
        # Default to balanced if current profile is unknown
        powerprofilesctl set balanced
        echo "Set to: balanced (default)"
        ;;
esac

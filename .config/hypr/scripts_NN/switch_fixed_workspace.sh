#!/bin/bash

TARGET_MONITOR_SHORTNAME=$1 # e.g., "left", "main", "right"

if [ -z "$TARGET_MONITOR_SHORTNAME" ]; then
    echo "Usage: $0 <monitor_shortname>"
    exit 1
fi

if [ "$TARGET_MONITOR_SHORTNAME" == "info" ]; then
    echo "Cannot switch to fixed workspace on InfoMonitor."
    exit 1
fi

TARGET_WS_NAME="fixed_${TARGET_MONITOR_SHORTNAME}"

# Get full monitor name from short name
MONITOR_NAME=""
case "$TARGET_MONITOR_SHORTNAME" in
    "left") MONITOR_NAME="HDMI-A-4" ;;
    "main") MONITOR_NAME="DP-2" ;;
    "right") MONITOR_NAME="DP-3" ;;
esac

if [ -z "$MONITOR_NAME" ]; then
    echo "Error: Invalid monitor shortname: $TARGET_MONITOR_SHORTNAME"
    exit 1
fi

# Check if the target workspace exists, if not, create it
hyprctl workspaces -j | grep -q "\"name\":\"$TARGET_WS_NAME\""
if [ $? -ne 0 ]; then
    hyprctl dispatch workspace "$TARGET_WS_NAME"
    hyprctl dispatch moveworkspacetomonitor "$TARGET_WS_NAME" "$MONITOR_NAME"
fi

hyprctl dispatch focusmonitor "$MONITOR_NAME"
hyprctl dispatch workspace "$TARGET_WS_NAME"

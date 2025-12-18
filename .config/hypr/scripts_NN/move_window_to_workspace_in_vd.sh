#!/bin/bash

TARGET_WS_ID=$1 # Can be a number (1-3)
OPTIONAL_TARGET_MONITOR_NAME=$2 # Optional: specific monitor name (e.g., HDMI-A-4)

# Determine the monitor to operate on
CURRENT_MONITOR=""
if [ -n "$OPTIONAL_TARGET_MONITOR_NAME" ]; then
    CURRENT_MONITOR="$OPTIONAL_TARGET_MONITOR_NAME"
else
    CURRENT_MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
fi

if [ -z "$CURRENT_MONITOR" ]; then
    echo "Error: Could not determine target monitor."
    exit 1
fi

MONITOR_SHORT_NAME=$(/home/florian/.dotfiles/public/.config/hypr/scripts/get_monitor_shortname.sh "$CURRENT_MONITOR")
if [ "$MONITOR_SHORT_NAME" == "info" ]; then
    echo "Cannot move window to InfoMonitor."
    exit 1
fi

# Get current VD ID
CURRENT_VD_ID=$(hyprctl activeworkspace -j | jq -r '.name' | sed -n 's/^vd\([0-9]\+\)_.*$/\1/p')
if [ -z "$CURRENT_VD_ID" ]; then
    # If not on a VD workspace, assume VD1
    CURRENT_VD_ID=1
fi

if [[ "$TARGET_WS_ID" =~ ^[0-9]+$ ]]; then
    # Target is a specific WS ID
    if (( TARGET_WS_ID >= 1 && TARGET_WS_ID <= 3 )); then
        TARGET_WS_NAME="vd${CURRENT_VD_ID}_ws${TARGET_WS_ID}_${MONITOR_SHORT_NAME}"

        # Check if the target workspace exists, if not, create it
        hyprctl workspaces -j | grep -q "\"name\":\"$TARGET_WS_NAME\""
        if [ $? -ne 0 ]; then
            hyprctl dispatch workspace "$TARGET_WS_NAME"
            hyprctl dispatch moveworkspacetomonitor "$TARGET_WS_NAME" "$CURRENT_MONITOR"
        fi

        hyprctl dispatch movetoworkspace "$TARGET_WS_NAME"
    else
        echo "Error: Workspace ID must be between 1 and 3."
        exit 1
    fi
else
    echo "Usage: $0 <WS_ID> [monitor_name]"
    exit 1
fi
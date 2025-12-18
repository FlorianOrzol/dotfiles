#!/bin/bash

TARGET_MONITOR_NAME=$1

if [ -z "$TARGET_MONITOR_NAME" ]; then
    # If no monitor name is provided, use the currently focused monitor
    TARGET_MONITOR_NAME=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    if [ -z "$TARGET_MONITOR_NAME" ]; then
        echo "Error: Could not determine target monitor."
        exit 1
    }
fi

# Get a short name for the monitor (e.g., "left", "main", "right")
# This assumes your monitor variables are set up in hyprland.conf
# and you can map them to short names. 
# For now, we'll use the full name, but a mapping would be better.
MONITOR_SHORT_NAME=""
case "$TARGET_MONITOR_NAME" in
    "HDMI-A-4") MONITOR_SHORT_NAME="left" ;;
    "DP-2") MONITOR_SHORT_NAME="main" ;;
    "DP-3") MONITOR_SHORT_NAME="right" ;;
    *) MONITOR_SHORT_NAME=$(echo "$TARGET_MONITOR_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g') ;;
esac

if [ -z "$MONITOR_SHORT_NAME" ]; then
    echo "Error: Could not determine short name for monitor $TARGET_MONITOR_NAME."
    exit 1
fi

# Find the next available dynamic workspace ID for this monitor
LAST_ID=0
for ws_name in $(hyprctl workspaces -j | jq -r '.[] | select(.monitor == "'""$TARGET_MONITOR_NAME"'"") | .name'); do
    if [[ "$ws_name" =~ ^d_${MONITOR_SHORT_NAME}_([0-9]+)$ ]]; then
        CURRENT_ID="${BASH_REMATCH[1]}"
        if (( CURRENT_ID > LAST_ID )); then
            LAST_ID=$CURRENT_ID
        fi
    fi
done

NEXT_ID=$((LAST_ID + 1))
NEW_WORKSPACE_NAME="d_${MONITOR_SHORT_NAME}_${NEXT_ID}"

# Switch to the new dynamic workspace
hyprctl dispatch workspace "$NEW_WORKSPACE_NAME"
#!/bin/bash

DIRECTION=$1 # "next" or "prev"
TARGET_MONITOR_NAME=$2 # e.g., "HDMI-A-4", "DP-2", "DP-3"

if [ -z "$DIRECTION" ] || [ -z "$TARGET_MONITOR_NAME" ]; then
    echo "Usage: $0 <next|prev> <monitor_name>"
    exit 1
fi

MONITOR_SHORT_NAME=$(/home/florian/.dotfiles/public/.config/hypr/scripts/get_monitor_shortname.sh "$TARGET_MONITOR_NAME")
if [ "$MONITOR_SHORT_NAME" == "info" ]; then
    echo "Cannot cycle workspaces on InfoMonitor."
    exit 1
fi

# Get current VD ID
CURRENT_VD_ID=$(hyprctl activeworkspace -j | jq -r '.name' | sed -n 's/^vd\([0-9]\+\)_.*$/\1/p')
if [ -z "$CURRENT_VD_ID" ]; then
    # If not on a VD workspace, assume VD1
    CURRENT_VD_ID=1
fi

# Get all relevant workspaces on the target monitor for the current VD
# Filter for workspaces belonging to the current VD and the target monitor
WORKSPACES_ON_MONITOR=$(hyprctl workspaces -j | \
    jq -r --arg mon "$TARGET_MONITOR_NAME" --arg vd "vd${CURRENT_VD_ID}_" \
    '.[] | select(.monitor == $mon and .name | startswith($vd) and (.name | contains("_ws"))) | .name' | sort -V)

# Get the name of the currently active workspace on the target monitor
CURRENT_WS_NAME=$(hyprctl monitors -j | jq -r --arg mon "$TARGET_MONITOR_NAME" '.[] | select(.name == $mon) | .activeWorkspace.name')

NEXT_WORKSPACE_NAME=""

if [ "$DIRECTION" == "next" ]; then
    FOUND_CURRENT=false
    for ws_name in $WORKSPACES_ON_MONITOR; do
        if [ "$FOUND_CURRENT" = true ]; then
            NEXT_WORKSPACE_NAME=$ws_name
            break
        fi
        if [ "$ws_name" == "$CURRENT_WS_NAME" ]; then
            FOUND_CURRENT=true
        fi
    done
    # If no next workspace found (i.e., at the end), loop back to the first
    if [ -z "$NEXT_WORKSPACE_NAME" ]; then
        NEXT_WORKSPACE_NAME=$(echo "$WORKSPACES_ON_MONITOR" | head -n 1)
    fi
elif [ "$DIRECTION" == "prev" ]; then
    PREV_WORKSPACE_NAME=""
    for ws_name in $WORKSPACES_ON_MONITOR; do
        if [ "$ws_name" == "$CURRENT_WS_NAME" ]; then
            NEXT_WORKSPACE_NAME=$PREV_WORKSPACE_NAME
            break
        fi
        PREV_WORKSPACE_NAME=$ws_name
    done
    # If no previous workspace found (i.e., at the beginning), loop back to the last
    if [ -z "$NEXT_WORKSPACE_NAME" ]; then
        NEXT_WORKSPACE_NAME=$(echo "$WORKSPACES_ON_MONITOR" | tail -n 1)
    fi
else
    echo "Invalid direction: $DIRECTION. Use 'next' or 'prev'."
    exit 1
fi

if [ -n "$NEXT_WORKSPACE_NAME" ]; then
    hyprctl dispatch focusmonitor "$TARGET_MONITOR_NAME"
    hyprctl dispatch workspace "$NEXT_WORKSPACE_NAME"
else
    echo "No other workspaces found on monitor $TARGET_MONITOR_NAME for VD $CURRENT_VD_ID."
    # If no workspaces exist, create the first one and switch to it
    FIRST_WS_NAME="vd${CURRENT_VD_ID}_ws1_${MONITOR_SHORT_NAME}"
    hyprctl dispatch workspace "$FIRST_WS_NAME"
    hyprctl dispatch moveworkspacetomonitor "$FIRST_WS_NAME" "$TARGET_MONITOR_NAME"
    hyprctl dispatch focusmonitor "$TARGET_MONITOR_NAME"
    hyprctl dispatch workspace "$FIRST_WS_NAME"
fi

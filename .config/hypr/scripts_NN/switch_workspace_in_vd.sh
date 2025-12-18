#!/bin/bash

TARGET_WS_ID=$1 # Can be a number (1-3) or "next" / "prev"
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
    echo "Cannot switch workspaces on InfoMonitor."
    exit 1
fi

# Get current VD ID
CURRENT_VD_ID=$(hyprctl activeworkspace -j | jq -r '.name' | sed -n 's/^vd\([0-9]\+\)_.*$/\1/p')
if [ -z "$CURRENT_VD_ID" ]; then
    # If not on a VD workspace, assume VD1
    CURRENT_VD_ID=1
fi

# Function to switch to a specific workspace within the current VD on the current monitor
switch_to_ws() {
    local ws_id=$1
    local target_ws_name="vd${CURRENT_VD_ID}_ws${ws_id}_${MONITOR_SHORT_NAME}"

    # Check if the target workspace exists, if not, create it
    hyprctl workspaces -j | grep -q "\"name\":\"$target_ws_name\""
    if [ $? -ne 0 ]; then
        hyprctl dispatch workspace "$target_ws_name"
        hyprctl dispatch moveworkspacetomonitor "$target_ws_name" "$CURRENT_MONITOR"
    fi

    hyprctl dispatch focusmonitor "$CURRENT_MONITOR"
    hyprctl dispatch workspace "$target_ws_name"
}

if [[ "$TARGET_WS_ID" =~ ^[0-9]+$ ]]; then
    # Target is a specific WS ID
    if (( TARGET_WS_ID >= 1 && TARGET_WS_ID <= 3 )); then
        switch_to_ws "$TARGET_WS_ID"
    else
        echo "Error: Workspace ID must be between 1 and 3."
        exit 1
    fi
elif [ "$TARGET_WS_ID" == "next" ] || [ "$TARGET_WS_ID" == "prev" ]; then
    # For next/prev, we need to get the current workspace on the target monitor
    # This requires getting the active workspace on the specific monitor, not just the focused one
    CURRENT_WS_NAME=$(hyprctl monitors -j | jq -r --arg mon "$CURRENT_MONITOR" '.[] | select(.name == $mon) | .activeWorkspace.name')
    CURRENT_WS_ID=$(echo "$CURRENT_WS_NAME" | sed -n 's/^vd[0-9]\+_ws\([0-9]\+\)_.*$/\1/p')

    if [ -z "$CURRENT_WS_ID" ]; then
        # If not on a numbered workspace, default to 1
        CURRENT_WS_ID=1
    fi

    NEXT_WS_ID=$CURRENT_WS_ID
    if [ "$TARGET_WS_ID" == "next" ]; then
        NEXT_WS_ID=$(( (CURRENT_WS_ID % 3) + 1 )) # Cycle 1-3
    else # prev
        NEXT_WS_ID=$(( (CURRENT_WS_ID - 2 + 3) % 3 + 1 )) # Cycle 1-3
    fi
    switch_to_ws "$NEXT_WS_ID"
else
    echo "Usage: $0 <WS_ID> | <next|prev> [monitor_name]"
    exit 1
fi
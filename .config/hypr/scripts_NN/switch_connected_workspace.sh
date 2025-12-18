#!/bin/bash

TARGET=$1 # Can be a number (e.g., "1") or "next" / "prev"

# Define your connected workspace sets here
# IMPORTANT: Adjust these based on how many connected sets you want
CONNECTED_SETS=(1 2 3) # Example: c1, c2, c3

# Get monitor names dynamically
# This assumes the monitors are consistently named in Hyprland
MONITOR_LEFT_NAME=$(hyprctl monitors -j | jq -r '.[] | select(.name == "HDMI-A-4") | .name')
MONITOR_MAIN_NAME=$(hyprctl monitors -j | jq -r '.[] | select(.name == "DP-2") | .name')
MONITOR_RIGHT_NAME=$(hyprctl monitors -j | jq -r '.[] | select(.name == "DP-3") | .name')

# Fallback if monitor names are not found (though they should be if connected)
if [ -z "$MONITOR_LEFT_NAME" ]; then MONITOR_LEFT_NAME="HDMI-A-4"; fi
if [ -z "$MONITOR_MAIN_NAME" ]; then MONITOR_MAIN_NAME="DP-2"; fi
if [ -z "$MONITOR_RIGHT_NAME" ]; then MONITOR_RIGHT_NAME="DP-3"; fi


# Function to switch to a specific connected set
switch_to_connected_set() {
    local set_id=$1
    hyprctl dispatch workspace "c${set_id}_left"
    hyprctl dispatch workspace "c${set_id}_main"
    hyprctl dispatch workspace "c${set_id}_right"
}

if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
    # Target is a specific ID
    if [[ " ${CONNECTED_SETS[@]} " =~ " ${TARGET} " ]]; then
        switch_to_connected_set "$TARGET"
    else
        echo "Error: Connected set $TARGET not defined."
        exit 1
    fi
elif [ "$TARGET" == "next" ] || [ "$TARGET" == "prev" ]; then
    # Target is next/prev
    CURRENT_CONNECTED_SET=""

    # Try to determine the current connected set based on the active workspace on main monitor
    # This is a heuristic and might need refinement
    ACTIVE_MAIN_WS=$(hyprctl activeworkspace -j | jq -r '.name')
    if [[ "$ACTIVE_MAIN_WS" =~ ^c([0-9]+)_main$ ]]; then
        CURRENT_CONNECTED_SET="${BASH_REMATCH[1]}"
    fi

    if [ -z "$CURRENT_CONNECTED_SET" ]; then
        echo "Could not determine current connected set. Switching to first set."
        switch_to_connected_set "${CONNECTED_SETS[0]}"
        exit 0
    fi

    NUM_SETS=${#CONNECTED_SETS[@]}
    for i in "${!CONNECTED_SETS[@]}"; do
        if [ "${CONNECTED_SETS[$i]}" == "$CURRENT_CONNECTED_SET" ]; then
            if [ "$TARGET" == "next" ]; then
                NEXT_INDEX=$(( (i + 1) % NUM_SETS ))
            else # prev
                NEXT_INDEX=$(( (i - 1 + NUM_SETS) % NUM_SETS ))
            fi
            switch_to_connected_set "${CONNECTED_SETS[$NEXT_INDEX]}"
            exit 0
        fi
    done
    echo "Error: Current connected set $CURRENT_CONNECTED_SET not found in defined sets."
    exit 1
else
    echo "Usage: $0 <ID> | <next|prev>"
    exit 1
fi
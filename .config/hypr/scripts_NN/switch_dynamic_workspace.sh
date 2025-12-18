#!/bin/bash

DIRECTION=$1 # "next" or "prev"

if [ -z "$DIRECTION" ]; then
    echo "Usage: $0 <next|prev>"
    exit 1
fi

# Get current monitor name
CURRENT_MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

if [ -z "$CURRENT_MONITOR" ]; then
    echo "Could not determine current monitor."
    exit 1
fi

# Get all DYNAMIC workspaces on the current monitor, sorted by name
# We sort by name to ensure d_left_1, d_left_10, d_left_2 is handled correctly
# by using sort -V (version sort)
DYNAMIC_WORKSPACES_ON_MONITOR=$(hyprctl workspaces -j | \
    jq -r --arg monitor "$CURRENT_MONITOR" \
    '.[] | select(.monitor == $monitor and .name | startswith("d_")) | .name' | sort -V)

# Get the name of the currently active workspace
CURRENT_WORKSPACE_NAME=$(hyprctl activeworkspace -j | jq -r '.name')

NEXT_WORKSPACE_NAME=""

if [ "$DIRECTION" == "next" ]; then
    FOUND_CURRENT=false
    for ws_name in $DYNAMIC_WORKSPACES_ON_MONITOR; do
        if [ "$FOUND_CURRENT" = true ]; then
            NEXT_WORKSPACE_NAME=$ws_name
            break
        fi
        if [ "$ws_name" == "$CURRENT_WORKSPACE_NAME" ]; then
            FOUND_CURRENT=true
        fi
    done
    # If no next workspace found (i.e., at the end), loop back to the first
    if [ -z "$NEXT_WORKSPACE_NAME" ]; then
        NEXT_WORKSPACE_NAME=$(echo "$DYNAMIC_WORKSPACES_ON_MONITOR" | head -n 1)
    fi
elif [ "$DIRECTION" == "prev" ]; then
    PREV_WORKSPACE_NAME=""
    for ws_name in $DYNAMIC_WORKSPACES_ON_MONITOR; do
        if [ "$ws_name" == "$CURRENT_WORKSPACE_NAME" ]; then
            NEXT_WORKSPACE_NAME=$PREV_WORKSPACE_NAME
            break
        fi
        PREV_WORKSPACE_NAME=$ws_name
    done
    # If no previous workspace found (i.e., at the beginning), loop back to the last
    if [ -z "$NEXT_WORKSPACE_NAME" ]; then
        NEXT_WORKSPACE_NAME=$(echo "$DYNAMIC_WORKSPACES_ON_MONITOR" | tail -n 1)
    fi
else
    echo "Invalid direction: $DIRECTION. Use 'next' or 'prev'."
    exit 1
fi

if [ -n "$NEXT_WORKSPACE_NAME" ]; then
    hyprctl dispatch workspace "$NEXT_WORKSPACE_NAME"
else
    echo "No other dynamic workspaces found on monitor $CURRENT_MONITOR."
fi

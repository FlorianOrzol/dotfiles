#!/bin/bash

WORKSPACE_NAME=$1
MONITOR_NAME=$2
PROGRAM_TO_OPEN=$3

if [ -z "$WORKSPACE_NAME" ] || [ -z "$MONITOR_NAME" ] || [ -z "$PROGRAM_TO_OPEN" ]; then
    echo "Usage: $0 <workspace_name> <monitor_name> <program_to_open>"
    exit 1
fi

# Check if the workspace already exists
hyprctl workspaces -j | grep -q "\"name\":\"$WORKSPACE_NAME\""

if [ $? -ne 0 ]; then
    # Workspace does not exist, create it and assign to monitor
    hyprctl dispatch workspace "$WORKSPACE_NAME"
    hyprctl dispatch moveworkspacetomonitor "$WORKSPACE_NAME" "$MONITOR_NAME"
    sleep 0.1 # Give Hyprland a moment to process
fi

# Move to the workspace
hyprctl dispatch workspace "$WORKSPACE_NAME"

# Open the program
hyprctl dispatch exec "$PROGRAM_TO_OPEN"

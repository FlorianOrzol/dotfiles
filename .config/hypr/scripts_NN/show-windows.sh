#!/bin/bash

# Get all workspaces with their names and IDs
WORKSPACES_MAP=$(hyprctl workspaces -j | jq -r '.[] | "\(.id) \(.name)"')

# Create an associative array for quick lookup
declare -A WS_NAMES
while read -r id name; do
    WS_NAMES[$id]="$name"
done <<< "$WORKSPACES_MAP"

# Get all clients
CLIENTS_JSON=$(hyprctl clients -j)

# Process each client
echo "$CLIENTS_JSON" | jq -r '.[] | "\(.workspace.id) \(.title) \(.initialClass)"' | while read -r ws_id title class; do
    # Get the workspace name from the map
    WORKSPACE_NAME="${WS_NAMES[$ws_id]}"

    # Fallback if name is not found (shouldn't happen if all workspaces are in the map)
    if [ -z "$WORKSPACE_NAME" ]; then
        WORKSPACE_NAME="ID:$ws_id"
    fi

    echo "${WORKSPACE_NAME}: ${title} (${class})"
done

echo
read -p "Press Enter to close"
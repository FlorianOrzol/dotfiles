#!/bin/bash

TARGET_VD=$1 # Can be a number (1-10) or "next" / "prev"

MONITORS=("HDMI-A-4" "DP-2" "DP-3") # Left, Main, Right monitors

# Store last active workspace for each monitor and VD
LAST_ACTIVE_WS_FILE="/tmp/hypr_last_active_ws"
mkdir -p $(dirname $LAST_ACTIVE_WS_FILE)

# Function to get the last active workspace for a given VD and monitor
get_last_active_ws() {
    local vd_id=$1
    local monitor_name=$2
    grep "^${vd_id}_${monitor_name}:" $LAST_ACTIVE_WS_FILE | cut -d: -f2
}

# Function to set the last active workspace for a given VD and monitor
set_last_active_ws() {
    local vd_id=$1
    local monitor_name=$2
    local ws_name=$3
    sed -i "/^${vd_id}_${monitor_name}:/d" $LAST_ACTIVE_WS_FILE
    echo "${vd_id}_${monitor_name}:${ws_name}" >> $LAST_ACTIVE_WS_FILE
}

# Function to get the current VD based on the main monitor's active workspace
get_current_vd() {
    local active_ws_main=$(hyprctl activeworkspace -j | jq -r '.name')
    if [[ "$active_ws_main" =~ ^vd([0-9]+)_ws[0-9]+_main$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        # Default to VD1 if not on a VD workspace
        echo "1"
    fi
}

# Function to switch to a specific virtual desktop
switch_to_vd() {
    local vd_id=$1
    for monitor in "${MONITORS[@]}"; do
        local monitor_shortname=$(/home/florian/.dotfiles/public/.config/hypr/scripts/get_monitor_shortname.sh "$monitor")
        local target_ws="vd${vd_id}_ws1_${monitor_shortname}" # Default to ws1

        # Check if there's a last active workspace for this VD and monitor
        local last_ws=$(get_last_active_ws "$vd_id" "$monitor_shortname")
        if [ -n "$last_ws" ]; then
            target_ws="$last_ws"
        fi

        # Check if the target workspace exists, if not, create it
        hyprctl workspaces -j | grep -q "\"name\":\"$target_ws\""
        if [ $? -ne 0 ]; then
            hyprctl dispatch workspace "$target_ws"
            hyprctl dispatch moveworkspacetomonitor "$target_ws" "$monitor"
        fi

        # Switch to the workspace on the respective monitor
        hyprctl dispatch focusmonitor "$monitor"
        hyprctl dispatch workspace "$target_ws"
    done
}

# Save current workspace before switching VD
CURRENT_VD=$(get_current_vd)
for monitor in "${MONITORS[@]}"; do
    local monitor_shortname=$(/home/florian/.dotfiles/public/.config/hypr/scripts/get_monitor_shortname.sh "$monitor")
    local active_ws=$(hyprctl activeworkspace -j | jq -r '.name')
    if [[ "$active_ws" =~ ^vd${CURRENT_VD}_ws[0-9]+_${monitor_shortname}$ ]]; then
        set_last_active_ws "$CURRENT_VD" "$monitor_shortname" "$active_ws"
    fi
done

if [[ "$TARGET_VD" =~ ^[0-9]+$ ]]; then
    # Target is a specific VD ID
    if (( TARGET_VD >= 1 && TARGET_VD <= 10 )); then
        switch_to_vd "$TARGET_VD"
    else
        echo "Error: Virtual Desktop ID must be between 1 and 10."
        exit 1
    fi
elif [ "$TARGET_VD" == "next" ] || [ "$TARGET_VD" == "prev" ]; then
    CURRENT_VD_ID=$(get_current_vd)
    NEXT_VD_ID=$CURRENT_VD_ID

    if [ "$TARGET_VD" == "next" ]; then
        NEXT_VD_ID=$(( (CURRENT_VD_ID % 10) + 1 )) # Cycle 1-10
    else # prev
        NEXT_VD_ID=$(( (CURRENT_VD_ID - 2 + 10) % 10 + 1 )) # Cycle 1-10
    fi
    switch_to_vd "$NEXT_VD_ID"
else
    echo "Usage: $0 <VD_ID> | <next|prev>"
    exit 1
fi

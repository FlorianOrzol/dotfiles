#!/bin/bash

DIRECTION=$1 # l, r, u, d

# Get active window address before attempting movefocus
OLD_ACTIVE_WINDOW_ADDRESS=$(hyprctl activewindow -j | jq -r '.address')

# Attempt standard movefocus
hyprctl dispatch movefocus "$DIRECTION"

# Give Hyprland a moment to process
sleep 0.05

# Get active window address after attempting movefocus
NEW_ACTIVE_WINDOW_ADDRESS=$(hyprctl activewindow -j | jq -r '.address')

# If focus did not change, try cross-workspace/monitor logic
if [ "$OLD_ACTIVE_WINDOW_ADDRESS" == "$NEW_ACTIVE_WINDOW_ADDRESS" ]; then
    # Get current monitor and its short name
    CURRENT_MONITOR_NAME=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    CURRENT_MONITOR_SHORTNAME=$(/home/florian/.dotfiles/public/.config/hypr/scripts/get_monitor_shortname.sh "$CURRENT_MONITOR_NAME")

    # Define monitor names (should match hyprland.conf)
    monitorLeft="HDMI-A-4"
    monitorMain="DP-2"
    monitorRight="DP-3"
    monitorInfo="HDMI-A-5"

    case "$DIRECTION" in
        "l") # Move left
            if [ "$CURRENT_MONITOR_NAME" == "$monitorMain" ]; then
                hyprctl dispatch focusmonitor "$monitorLeft"
            elif [ "$CURRENT_MONITOR_NAME" == "$monitorRight" ]; then
                hyprctl dispatch focusmonitor "$monitorMain"
            elif [ "$CURRENT_MONITOR_NAME" == "$monitorInfo" ]; then
                hyprctl dispatch focusmonitor "$monitorRight"
            fi
            ;;
        "r") # Move right
            if [ "$CURRENT_MONITOR_NAME" == "$monitorMain" ]; then
                hyprctl dispatch focusmonitor "$monitorRight"
            elif [ "$CURRENT_MONITOR_NAME" == "$monitorLeft" ]; then
                hyprctl dispatch focusmonitor "$monitorMain"
            elif [ "$CURRENT_MONITOR_NAME" == "$monitorRight" ]; then
                hyprctl dispatch focusmonitor "$monitorInfo"
            fi
            ;;
        "u") # Move up (cycle prev workspace on current monitor)
            /home/florian/.dotfiles/public/.config/hypr/scripts/switch_workspace_in_vd.sh prev "$CURRENT_MONITOR_NAME"
            ;;
        "d") # Move down (cycle next workspace on current monitor)
            /home/florian/.dotfiles/public/.config/hypr/scripts/switch_workspace_in_vd.sh next "$CURRENT_MONITOR_NAME"
            ;;
    esac
fi
#!/bin/bash
DIR=$1

# Get the current active window address and position
ACTIVE_WINDOW=$(hyprctl activewindow -j | jq -r '.address')
OLD_MON=$(hyprctl activewindow -j | jq -r '.monitor')
OLD_X=$(hyprctl activewindow -j | jq -r '.at[0]')
OLD_Y=$(hyprctl activewindow -j | jq -r '.at[1]')

# Try to move the window within the current monitor's layout first
hyprctl dispatch movewindow $DIR > /dev/null

# Small sleep to let hyprland update positions
sleep 0.05

NEW_MON=$(hyprctl activewindow -j | jq -r '.monitor')
NEW_X=$(hyprctl activewindow -j | jq -r '.at[0]')
NEW_Y=$(hyprctl activewindow -j | jq -r '.at[1]')

# If the window didn't move (it hit the screen edge), try to move it to the adjacent monitor
if [ "$OLD_MON" == "$NEW_MON" ] && [ "$OLD_X" == "$NEW_X" ] && [ "$OLD_Y" == "$NEW_Y" ]; then
    CURRENT_MON=$OLD_MON
    
    # Temporarily move focus to find the adjacent monitor
    hyprctl dispatch focusmonitor $DIR > /dev/null
    TARGET_MON=$(hyprctl activeworkspace -j | jq -r '.monitor')
    
    # If the monitor actually changed, it means there is a monitor in that direction
    if [ "$CURRENT_MON" != "$TARGET_MON" ]; then
        # Focus back to original monitor and window
        hyprctl dispatch focusmonitor "$CURRENT_MON" > /dev/null
        hyprctl dispatch focuswindow address:"$ACTIVE_WINDOW" > /dev/null
        
        # Move the window to the target monitor
        hyprctl dispatch movewindow mon:"$TARGET_MON" > /dev/null
        
        # Follow the window to the new monitor
        hyprctl dispatch focusmonitor "$TARGET_MON" > /dev/null
    fi
fi

# Function: fish_prompt
# Description: Custom prompt function for the Fish shell.
# This function defines the appearance and content of the command prompt,
# including colors, status indicators, current directory, Git status, and Vi-mode.
function fish_prompt
    # Define prompt colors for various elements using hexadecimal or standard color codes.
    set -l color_fg_hellgrey (set_color 585858) # Light grey foreground.
    set -l color_fg_grey (set_color 303030)     # Dark grey foreground.
    # Note: These background colors are defined using ANSI escape codes for 256-color support.
    set -l color_bg_darkgrey (printf "\033[48;5;240m") # Dark grey background (index 240).
    set -l color_bg_lightgrey (printf "\033[48;5;236m") # Lighter grey background (index 236).
    set -l color_fg_blue (set_color 0FABFF)     # Custom blue foreground.

    # Standard color definitions for common prompt elements.
    set -l color_normal (set_color normal) # Reset to normal text color.
    set -l color_cwd (set_color cyan)      # Current working directory color.
    set -l color_status (set_color red)    # Default status color (e.g., for errors).
    set -l color_fg_git (set_color yellow) # Git branch name color.
    set -l color_fg_git_status (set_color CD6600) # Git status indicator color.
	
    # Default status sign character.
    set -l status_sign "ᐱ" 

    # Determine the status icon and color based on the last command's exit status.
    # The `last_status` variable is set by the `save_status` function on `fish_postexec`.
    if set -q last_status
        if test $last_status -eq 0
            # If the last command succeeded (exit code 0), set status color to green and icon to checkmark.
            set color_status (set_color 00FF00) # Green for success.
            set status_sign ""               # Checkmark icon.
        else
            # If the last command failed (non-zero exit code), set status color to red and icon to cross.
            set color_status (set_color red)    # Red for failure.
            set status_sign "✘"               # Cross icon.
        end
    else
        # Default status for the first command or if last_status is not set (e.g., initial prompt).
        set color_status (set_color 00FF00) # Green by default.
        set status_sign ""               # Checkmark by default.
    end

	# 1. Determine the current Vi-mode (normal, insert, visual).
    set -l mode_char # Character representing the current mode.
    set -l mode_col  # Color for the mode indicator.
    switch $fish_bind_mode
        case default # Normal mode (similar to Vim's normal mode).
            set mode_char "N"
            set mode_col red 
        case insert # Insert mode.
            set mode_char "I"
            set mode_col green
        case visual # Visual mode.
            set mode_char "V"
            set mode_col magenta
    end

	# Assemble the mode prompt string with its character and color.
	set -l mode_prompt (set_color $mode_col)""$color_bg_lightgrey$color_fg_hellgrey

    # Get Git repository information if the current directory is within one.
    # `__fish_git_prompt` provides the branch name; `__fish_git_prompt_informative_status` provides status indicators.
    set -l git_info ""
    if string match -q '*(*' (__fish_git_prompt) # Check if `__fish_git_prompt` returns non-empty output (i.e., in a Git repo).
        set git_info "$color_fg_git " (__fish_git_prompt) "$color_fg_git_status " (__fish_git_prompt_informative_status)
    end

	# Format the current working directory path, replacing $HOME with '~'.
	set -l mypath (string replace $HOME '~' (pwd))

    # Construct and print the multi-line prompt.
    # Line 1: Contains status, mode, and current path.
    echo -s "$color_fg_hellgrey" "╭─" "$color_fg_grey" "" "$color_status" "$color_bg_lightgrey" "$status_sign" $color_fg_hellgrey"  $mode_prompt ╱ "  "$color_fg_blue" $mypath " " "$git_info" "$color_normal" "$color_fg_grey" "▓▒░" "$color_normal" 
    # Line 2: The prompt indicator, colored light grey.
    echo -s "$color_fg_hellgrey" "╰─ " "$color_normal"
end

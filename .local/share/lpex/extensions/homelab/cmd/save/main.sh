#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Saves a command as shortcut without running it.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Prompts for missing values and stores the shortcut.
# ==============================================================================
function extension_start {
    local alias="$ARG_ALIAS"
    local cmd="${ARG_CMD[*]}"           # --multi delivers words — join them back

    # Ask for the alias when none was given
    if [[ -z "$alias" ]]; then
        lx input @alias --prompt "Alias" || return 1
    fi

    # Ask for the command when none was given
    if [[ -z "$cmd" ]]; then
        lx input @cmd --prompt "Command" || return 1
    fi

    # Validation, uniqueness and insert live in the shared helper
    cmd_save_alias "$alias" "$cmd" "${ARG_DESCRIPTION:-}" "${ARG_DEVICE[@]}"
}

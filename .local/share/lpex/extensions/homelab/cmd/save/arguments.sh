#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd save'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for saving a shortcut without running it.
# @usage       : lpex homelab cmd save <alias> --cmd <command> --device <device...> [--description <text>]
#
# @options     : <alias>        | New alias, no spaces (positional, prompted when missing)
#                --cmd          | Command to store (prompted when missing)
#                --device       | One or more target devices (fzf multi-select)
#                --description  | Short description (optional)
# ==============================================================================
function arguments {
    # Alias is free text — no list to choose from
    arg_direct @alias --description "New alias (letters, digits, . _ -)"

    # --multi collects unquoted words up to the next flag
    arg_value @cmd --description "Command to store" --multi

    # Devices: multi-select from nodes, live containers and VMs
    arg_value @device --description "Target device(s)" --fzf --multi \
        --option-cmd "get_cmd_devices"

    arg_value @description --description "Optional description"
}

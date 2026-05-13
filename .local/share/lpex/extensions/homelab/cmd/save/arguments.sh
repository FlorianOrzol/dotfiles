#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd save'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for saving a command entry to the DB.
# @usage       : lpex homelab cmd save --alias <name> --cmd <command> --device <device(s)> [--description <text>]
#
# @options     : --alias        | Alias name, unique per device (required)
#                --cmd          | Shell command to store (required)
#                --device       | Target device(s), multi-select (required)
#                --description  | Short description of the command (optional)
# ==============================================================================
function arguments {
    arg_value @alias       --description "Alias name (unique per device)" --fzf
    arg_value @cmd         --description "Shell command to store" --fzf
    arg_value @device      --description "Target device(s)" --fzf --multi \
                               --option-cmd "get_all_devices"
    arg_value @description --description "Optional description"
}

#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd delete'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for deleting a saved command entry.
# @usage       : lpex homelab cmd delete --alias <name> --device <device>
#
# @options     : --alias   | Alias to delete, shown with device context (required)
#                --device  | Target device the alias is saved for (required)
# ==============================================================================
function arguments {
    arg_value @alias  --description "Alias to delete" --fzf \
                          --option-cmd "get_cmd_aliases"
    arg_value @device --description "Target device" --fzf --multi\
                          --option-cmd "get_all_devices"
}

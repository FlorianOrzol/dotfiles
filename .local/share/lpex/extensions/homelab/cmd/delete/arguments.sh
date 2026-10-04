#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd delete'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for deleting a saved shortcut.
# @usage       : lpex homelab cmd delete <alias>
#
# @options     : <alias> | Shortcut to delete (positional, fzf)
# @notes       : Removing single devices is 'cmd edit <alias> --remove-device'.
# ==============================================================================
function arguments {
    arg_direct @alias --description "Shortcut to delete" --fzf --option-cmd "get_cmd_aliases"
}

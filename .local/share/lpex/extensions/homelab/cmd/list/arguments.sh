#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd list'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for listing saved command entries.
# @usage       : lpex homelab cmd list [--device <device>] [--alias <name>]
#
# @options     : --device  | Filter results by device (optional)
#                --alias   | Filter results by alias (optional)
# ==============================================================================
function arguments {
    arg_value @device --description "Filter by device" \
                          --option-cmd "get_all_devices"
    arg_value @alias  --description "Filter by alias" \
                          --option-cmd "get_cmd_aliases"
}

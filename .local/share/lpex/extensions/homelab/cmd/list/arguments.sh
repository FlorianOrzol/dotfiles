#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd list'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for listing saved shortcuts.
# @usage       : lpex homelab cmd list [--device <device>]
#
# @options     : --device | Show only shortcuts saved for this device (optional)
# ==============================================================================
function arguments {
    arg_value @device --description "Filter by device" --option-cmd "get_cmd_devices"
}

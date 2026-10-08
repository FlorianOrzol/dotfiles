#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly status'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the device and the raw switch.
# @usage       : lpex shelly status <device> [--raw]
#
# @options     : <device> | id, MAC or IP (positional, fzf)
#                --raw    | Print the full API answer (status + settings/config) as JSON
# ==============================================================================
function arguments {
    arg_direct @device --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
    arg_flag   @raw    --description "Full API answer as JSON (status + settings)"
}

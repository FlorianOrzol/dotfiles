#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly reboot'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the device.
# @usage       : lpex shelly reboot <device> [--yes]
#
# @options     : <device> | id, MAC or IP (positional, fzf)
#                --yes    | Do not ask
# ==============================================================================
function arguments {
    arg_direct @device --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
    arg_flag   @yes    --description "Do not ask"
}

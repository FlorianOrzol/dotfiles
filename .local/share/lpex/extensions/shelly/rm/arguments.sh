#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly rm'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the device to remove.
# @usage       : lpex shelly rm <device>
#
# @options     : <device> | id, MAC or IP (positional, fzf)
# @notes       : The device itself is not touched; 'scan' finds it again.
# ==============================================================================
function arguments {
    arg_direct @device --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
}

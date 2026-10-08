#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly switch'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers device, action and the output options.
# @usage       : lpex shelly switch <device> <on|off|toggle> [--channel <n>] [--brightness <1-100>]
#
# @options     : <device>     | id, MAC or IP (positional, fzf)
#                <action>     | on, off or toggle (positional, fzf)
#                --channel    | Output number for devices with several (default 0)
#                --brightness | Lights only: brightness 1-100 together with on
# ==============================================================================
function arguments {
    arg_direct @device --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
    arg_direct @action --description "Action" --fzf \
        --option "on # switch on" \
        --option "off # switch off" \
        --option "toggle # invert the current state"
    arg_value  @channel    --description "Output number (default 0)"
    arg_value  @brightness --description "Lights: brightness 1-100"
}

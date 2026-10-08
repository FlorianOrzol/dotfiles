#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly cover'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers device, action and the channel.
# @usage       : lpex shelly cover <device> <open|close|stop|0-100> [--channel <n>]
#
# @options     : <device>  | id, MAC or IP (positional, fzf)
#                <action>  | open, close, stop or a position 0 (closed) – 100 (open)
#                --channel | Cover number (default 0)
# @notes       : Positions need a calibrated cover (Shelly UI: calibrate once).
# ==============================================================================
function arguments {
    arg_direct @device --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
    arg_direct @action --description "Action or position 0-100" --fzf \
        --option "open # fully open" \
        --option "close # fully close" \
        --option "stop # stop moving" \
        --option "50 # position in percent (0 = closed, 100 = open)"
    arg_value  @channel --description "Cover number (default 0)"
}

#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly config show'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers device and filter.
# @usage       : lpex shelly config show <device> [--filter <regex>]
#
# @options     : <device> | id, MAC or IP (positional, fzf)
#                --filter | Only lines matching this regex (e.g. mqtt, relays.0, wifi)
# ==============================================================================
function arguments {
    arg_direct @device --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
    arg_value  @filter --description "Only lines matching this regex (mqtt, wifi, relays.0 …)"
}

#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly scan'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for scanning the LAN.
# @usage       : lpex shelly scan [--range <cidr…>] [--add]
#
# @options     : --range | CIDR range(s), max /20 each (default: SHELLY_SCAN_RANGES)
#                --add   | Add new devices to the inventory (otherwise only listed)
# ==============================================================================
function arguments {
    arg_value @range --description "CIDR range(s) to probe (default from config)" --multi
    arg_flag  @add   --description "Add new devices to the inventory"
}

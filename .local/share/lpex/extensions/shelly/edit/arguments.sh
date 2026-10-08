#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly edit'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the device and the inventory fields that can be changed.
# @usage       : lpex shelly edit <device> [--id <new>] [--name <text>] [--room <room>]
#                                          [--profile <name>] [--notes <text>]
#
# @options     : <device>  | id, MAC or IP (positional, fzf)
#                --id      | New id (CLI key, later MQTT login) — a-z 0-9 and '-'
#                --name    | Display name in the inventory (the device keeps its own)
#                --room    | Room (free text, offered from existing rooms)
#                --profile | Settings profile for 'config apply' (phase 3)
#                --notes   | Free notes
# @notes       : Changes only the inventory. Writing name/settings to the device
#                comes with 'shelly config' (phase 3).
# ==============================================================================
function arguments {
    arg_direct @device  --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
    arg_value  @id      --description "New id (a-z, 0-9, '-')"
    arg_value  @name    --description "Display name in the inventory"
    arg_value  @room    --description "Room" --option-cmd "get_shelly_rooms"
    arg_value  @profile --description "Settings profile (phase 3)"
    arg_value  @notes   --description "Free notes"
}

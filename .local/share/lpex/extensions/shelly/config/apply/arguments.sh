#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly config apply'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers device, profile and the part selection.
# @usage       : lpex shelly config apply <device> [--profile <name>] [--only cloud,mqtt,auth] [--yes]
#
# @options     : <device>  | id, MAC or IP (positional, fzf)
#                --profile | Profile name (default: the device's profile from the inventory)
#                --only    | Comma list of parts: cloud, mqtt, auth (default: all)
#                --yes     | Do not ask before changing the device
# ==============================================================================
function arguments {
    arg_direct @device  --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
    arg_value  @profile --description "Profile (default: the device's own)"
    arg_value  @only    --description "Parts: cloud,mqtt,auth (comma list)" \
        --option "cloud" --option "mqtt" --option "auth" --option "cloud,mqtt" --option "mqtt,auth"
    arg_flag   @yes     --description "Do not ask before changing the device"
}

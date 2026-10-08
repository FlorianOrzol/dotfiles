#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly config set'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the device and the settings that can be changed directly.
# @usage       : lpex shelly config set <device> [--name <text>] [--cloud on|off] [--mqtt on|off]
#                       [--auth on|off] [--default-state on|off|last|switch [--channel <n>]]
#                       [--wifi static|dhcp [--ip <address>]]
#
# @options     : <device>        | id, MAC or IP (positional, fzf)
#                --name          | Device name (written to the device and the inventory)
#                --cloud         | Shelly cloud on/off
#                --mqtt          | MQTT on (server/password from config, login = id) or off
#                --auth          | Device login on (password from config) or off
#                --default-state | Power-on behaviour of an output
#                --channel       | Output number for --default-state (default 0)
#                --wifi          | Re-address the device: static (with --ip) or dhcp
#                --ip            | New static address for --wifi static
# @notes       : Everything else: 'lpex shelly config raw'.
# ==============================================================================
function arguments {
    arg_direct @device --description "Device (id, MAC or IP)" --fzf --option-cmd "get_shelly_devices"
    arg_value  @name   --description "Device name (device + inventory)"
    arg_value  @cloud  --description "Shelly cloud" --option "on" --option "off"
    arg_value  @mqtt   --description "MQTT (server/password from config, login = id)" --option "on" --option "off"
    arg_value  @auth   --description "Device login (password from config)" --option "on" --option "off"
    arg_value  @default_state --description "Power-on behaviour" \
        --option "on # always on after power loss" \
        --option "off # always off after power loss" \
        --option "last # restore the last state" \
        --option "switch # follow the wall switch"
    arg_value  @channel --description "Output number for --default-state (default 0)"
    arg_value  @wifi    --description "Re-address: static (with --ip) or dhcp" --option "static" --option "dhcp"
    arg_value  @ip      --description "New static address (with --wifi static)"
}

#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly setup'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the values for a new device — missing ones are asked.
# @usage       : lpex shelly setup [--name <text>] [--id <id>] [--room <room>]
#                                  [--ip <address> | --dhcp] [--profile <name>]
#                                  [--ap <ssid>] [--ssid <ssid>]
#
# @options     : --name    | Device name (asked when missing)
#                --id      | Inventory id / MQTT login (default: slug of the name)
#                --room    | Room in the inventory
#                --ip      | Static address (default: first free in SHELLY_IP_POOL, asked)
#                --dhcp    | DHCP instead of a static address
#                --profile | Settings profile (default: default)
#                --ap      | Access point to use (default: chosen from the 'shelly*' networks)
#                --ssid    | WLAN to join (default: SHELLY_WIFI_SSID)
# @notes       : Needs wlan0; starts iwd with sudo when it is not running and stops
#                it again at the end. The LAN connection is not touched.
# ==============================================================================
function arguments {
    arg_value @name    --description "Device name"
    arg_value @id      --description "Inventory id / MQTT login (default: from the name)"
    arg_value @room    --description "Room" --option-cmd "get_shelly_rooms"
    arg_value @ip      --description "Static address (default: suggested from SHELLY_IP_POOL)"
    arg_flag  @dhcp    --description "DHCP instead of a static address"
    arg_value @profile --description "Settings profile (default: default)"
    arg_value @ap      --description "Shelly access point (default: chosen from a scan)"
    arg_value @ssid    --description "WLAN to join (default from config)"
}

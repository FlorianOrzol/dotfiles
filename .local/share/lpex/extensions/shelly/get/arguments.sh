#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly get'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the targets, the wanted values and the output format.
# @usage       : lpex shelly get <device[,device…]|all> [--field <name…>] [--path <api-path…>]
#                                [--room <room>] [--cached] [--json]
#
# @options     : <device> | id, MAC or IP; several comma-separated; 'all' (positional, fzf)
#                --field  | Common values, same for every generation (several allowed)
#                --path   | Any value of the raw API answer: status.<…> or config.<…>
#                --room   | Only devices of one room (with 'all')
#                --cached | No live query — last known state from the inventory
#                --json   | Machine output: {"<id>": {"<field>": value, …}, …}
# @notes       : One device and one value prints the bare value — made for scripts.
# ==============================================================================
function arguments {
    arg_direct @device --description "Device (id, MAC, IP), comma-separated list or all" --fzf \
        --option "all # every device in the inventory" --option-cmd "get_shelly_devices"
    arg_value  @field  --description "Common values (several allowed)" --multi \
        --option "online # answered just now (true/false)" \
        --option "state # outputs: on, off, on 21%, stop 50%" \
        --option "power # current power in W (sum of all channels)" \
        --option "energy # energy counter total in kWh" \
        --option "temp # device temperature in °C" \
        --option "rssi # WLAN signal in dBm" \
        --option "ssid # WLAN name" \
        --option "mqtt # MQTT connected (true/false)" \
        --option "cloud # cloud connected (true/false)" \
        --option "update # available firmware version, empty when current" \
        --option "uptime # seconds since the last start" \
        --option "ip # address from the inventory" \
        --option "name # device name" \
        --option "room # room from the inventory" \
        --option "model # model code (SHPLG-S, PlusPlugS …)" \
        --option "gen # generation" \
        --option "fw # firmware version" \
        --option "mac # MAC address"
    arg_value  @path   --description "Raw API path: status.<…> / config.<…> (see 'status --raw')" --multi
    arg_value  @room   --description "Only devices of this room" --option-cmd "get_shelly_rooms"
    arg_flag   @cached --description "No live query — last known state from the inventory"
    arg_flag   @json   --description "JSON output keyed by device id"
}

#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly list'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the view and filter options of the overview.
# @usage       : lpex shelly list [--view basic|energy|network|firmware]
#                                 [--online|--offline] [--on|--off] [--room <room>] [--cached]
#
# @options     : --view    | Column set (default: basic)
#                --online  | Only devices that answered
#                --offline | Only devices that did not answer
#                --on      | Only devices with at least one output on / cover not closed
#                --off     | Only devices with every output off
#                --room    | Only devices of one room
#                --cached  | No live query — last known state from the inventory
# ==============================================================================
function arguments {
    arg_value @view --description "Column set" \
        --option "basic # name, room, model, online, state, power, temperature" \
        --option "energy # state, power, energy total — sorted by power" \
        --option "network # IP, mode, WLAN, signal, MQTT, cloud, login" \
        --option "firmware # model, generation, firmware, available update"
    arg_flag  @online  --description "Only devices that answered"
    arg_flag  @offline --description "Only devices that did not answer"
    arg_flag  @on      --description "Only devices with an output on (or a cover not closed)"
    arg_flag  @off     --description "Only devices with every output off"
    arg_value @room    --description "Only devices of this room" --option-cmd "get_shelly_rooms"
    arg_flag  @cached  --description "No live query — last known state from the inventory"
}

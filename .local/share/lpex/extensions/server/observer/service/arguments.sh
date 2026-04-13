#!/bin/bash
# ==============================================================================
# @meta_module      : server observer service
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server observer service'.
#
# @arg_values       : --node    | Target Observer node (pi1 or pi2)
# @arg_values       : --name    | Name of the systemd unit to control
# @arg_flags        : --start   | Start the unit
# @arg_flags        : --stop    | Stop the unit
# @arg_flags        : --restart | Restart the unit
# @arg_flags        : --enable  | Enable the unit at boot
# @arg_flags        : --disable | Disable the unit at boot
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"

    arg_flag @start   --description "Start the service/timer"
    arg_flag @stop    --description "Stop the service/timer"
    arg_flag @restart --description "Restart the service/timer"
    arg_flag @enable  --description "Enable the unit at boot"
    arg_flag @disable --description "Disable the unit at boot"
    arg_flag @status  --description "Show systemctl status output for the unit"

    arg_value @name --description "Name of the systemd unit (e.g. obs-heartbeat.timer)"
}

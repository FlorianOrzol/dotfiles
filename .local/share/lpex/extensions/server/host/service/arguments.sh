#!/bin/bash
# ==============================================================================
# @meta_module      : server host service
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-13
#
# @desc_short       : Declares CLI arguments for 'server host service'.
#
# @arg_values       : --node    | Target Proxmox node (pve101, pve102, pve103)
# @arg_values       : --name    | Name of the systemd unit to control
# @arg_flags        : --start   | Start the unit
# @arg_flags        : --stop    | Stop the unit
# @arg_flags        : --restart | Restart the unit
# @arg_flags        : --enable  | Enable the unit at boot
# @arg_flags        : --disable | Disable the unit at boot
# @arg_flags        : --status  | Show systemctl status output
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Proxmox node" \
        --option "pve101" --option "pve102" --option "pve103"

    arg_flag @start   --description "Start the service/timer"
    arg_flag @stop    --description "Stop the service/timer"
    arg_flag @restart --description "Restart the service/timer"
    arg_flag @enable  --description "Enable the unit at boot"
    arg_flag @disable --description "Disable the unit at boot"
    arg_flag @status  --description "Show systemctl status output for the unit"

    arg_value @name --description "Name of the systemd unit (e.g. pct_live_list.service)"
}

#!/bin/bash
# ==============================================================================
# @meta_module      : server host service
# @meta_file        : main.sh
# @meta_date        : 2026-04-13
#
# @desc_short       : Controls systemd services and timers on a Proxmox host.
# @desc_detailed    : Dispatches systemctl actions (start, stop, restart, enable,
# @desc_detailed    : disable, status) on the target PVE node via SSH.
# @desc_detailed    : USER_PVE is root on Proxmox — no sudo required.
#
# @arg_values       : --node    | Target Proxmox node (pve101, pve102, pve103)
# @arg_values       : --name    | Name of the systemd unit
# @arg_flags        : --start   | Start the unit
# @arg_flags        : --stop    | Stop the unit
# @arg_flags        : --restart | Restart the unit
# @arg_flags        : --enable  | Enable the unit at boot
# @arg_flags        : --disable | Disable the unit at boot
# @arg_flags        : --status  | Show systemctl status output
#
# @exit_codes       : 0 | systemctl action dispatched successfully
# @exit_codes       : 1 | Missing argument or SSH command failed
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_PVE"

    local node="${ARG_NODE[0]}"
    local service_name="${ARG_NAME[0]}"

    if [[ -z "$node" || -z "$service_name" ]]; then
        output --error "Usage: lpex server host service --node <node> --name <unit> [--start|--stop|--restart|--enable|--disable|--status]"
        return 1
    fi

    # Resolve IP from config variable (e.g. IP_PVE101)
    local node_upper="${node^^}"
    local ip_var="IP_${node_upper}"
    local ip="${!ip_var}"

    if [[ -z "$ip" ]]; then
        output --error "IP not found for $node (${ip_var} not set in config.conf)."
        return 1
    fi

    # ==========================================================================
    # --- Feature: Status Display ---
    # ==========================================================================
    if (( ARG_STATUS )); then
        output --section "Status: $service_name on $node"
        # [LOGIC] --no-pager prevents systemctl from opening 'less' interactively.
        # USER_PVE is root on Proxmox — no sudo needed.
        ssh "$USER_PVE@$ip" "systemctl status $service_name --no-pager"
        return 0
    fi

    # Map the provided flag to a systemctl action string
    local action=""
    (( ARG_START ))   && action="start"
    (( ARG_STOP ))    && action="stop"
    (( ARG_RESTART )) && action="restart"
    (( ARG_ENABLE ))  && action="enable"
    (( ARG_DISABLE )) && action="disable"

    if [[ -z "$action" ]]; then
        output --error "Please specify an action: --start, --stop, --restart, --enable, --disable, --status"
        return 1
    fi

    output --info "Executing 'systemctl $action $service_name' on $node..."

    # [LOGIC] USER_PVE is root on Proxmox hosts — systemctl can be called directly
    # without sudo, unlike the observer where fadmin requires sudo for system units.
    if lx cmd --run "ssh $USER_PVE@$ip 'systemctl $action $service_name'"; then
        output --ok "$action successful: $service_name on $node"
    else
        output --error "Failed to $action '$service_name' on $node."
    fi
}

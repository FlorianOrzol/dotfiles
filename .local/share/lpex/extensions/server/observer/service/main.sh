#!/bin/bash
# ==============================================================================
# @meta_module      : server observer service
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Controls systemd services and timers on an Observer Pi.
# @desc_detailed    : Dispatches systemctl actions (start, stop, restart, enable,
# @desc_detailed    : disable) on the target Observer node via sudo over SSH.
# @desc_detailed    : The -t flag ensures interactive sudo password prompts work.
#
# @arg_values       : --node    | Target Observer node (pi1, pi2)
# @arg_values       : --name    | Name of the systemd unit (e.g. obs-heartbeat.timer)
# @arg_flags        : --start   | Start the service/timer
# @arg_flags        : --stop    | Stop the service/timer
# @arg_flags        : --restart | Restart the service/timer
# @arg_flags        : --enable  | Enable the unit at boot
# @arg_flags        : --disable | Disable the unit at boot (inverse of --enable)
#
# @exit_codes       : 0 | systemctl action dispatched successfully
# @exit_codes       : 1 | Missing argument or SSH command failed
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_OBSERVER"

    local node="${ARG_NODE[0]}"
    local service_name="${ARG_NAME[0]}"

    if [[ -z "$node" || -z "$service_name" ]]; then
        output --error "Usage: lpex server observer service --node <pi> --name <unit> [--start|--stop|--restart|--enable|--disable]"
        return 1
    fi

    local ip=$(get_observer_ip "$node")

    # Map the provided flag to a systemctl action string
    local action=""
    (( ARG_START ))   && action="start"
    (( ARG_STOP ))    && action="stop"
    (( ARG_RESTART )) && action="restart"
    (( ARG_ENABLE ))  && action="enable"
    (( ARG_DISABLE )) && action="disable"

    # ==========================================================================
    # --- Feature: Status Display ---
    # Prints the full 'systemctl status' output — useful after start/stop to
    # confirm the unit is in the expected state without needing observer/logs.
    # ==========================================================================
    if (( ARG_STATUS )); then
        output --section "Status: $service_name on $node"
        # [LOGIC] --no-pager prevents systemctl from opening 'less' interactively;
        # -t is kept so the output has correct terminal colours over SSH.
        ssh -t "$USER_OBSERVER@$ip" "systemctl status $service_name --no-pager"
        return 0
    fi

    if [[ -z "$action" ]]; then
        output --error "Please specify an action (--start, --stop, --restart, --enable, --disable, --status)."
        return 1
    fi

    output --info "Executing 'sudo systemctl $action $service_name' on $node..."

    # [LOGIC] -t allocates a pseudo-TTY so sudo can prompt for a password interactively
    # if the observer user is not configured with NOPASSWD for systemctl.
    if lx cmd --run "ssh -t $USER_OBSERVER@$ip 'sudo systemctl $action $service_name'"; then
        output --ok "$action successful."
    else
        output --error "Failed to $action '$service_name'."
    fi
}

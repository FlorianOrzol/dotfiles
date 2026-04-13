#!/bin/bash
# ==============================================================================
# @meta_module      : server container control
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Manages the power state of an LXC container via pct.
# @desc_detailed    : Sends start, stop, or restart signals to a container on the
# @desc_detailed    : active Proxmox host using pct commands over SSH.
#
# @arg_values       : --ctid    | Target container ID (fzf-selectable)
# @arg_flags        : --start   | Power on the container
# @arg_flags        : --stop    | Gracefully stop the container
# @arg_flags        : --restart | Reboot the container
#
# @exit_codes       : 0 | Signal dispatched successfully
# @exit_codes       : 1 | Missing ctid or no action specified
# ==============================================================================

function extension_start() {
    
    # --- 1. Resolve State ---
    enforce_config_var "USER_PVE"

    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]}"

    if [[ -z "$ctid" ]]; then
        output --error "Container ID required (--ctid)."
        return 1
    fi

    # ==========================================================================
    # --- Feature: Power State Management ---
    # Dispatches the appropriate signal and logs the event to the audit trail.
    # ==========================================================================
    if (( ARG_START )); then
        if lx cmd --run "ssh $USER_PVE@$active_host pct start $ctid" --log --log-tags "lxc,start" --error-msg "Failed to start CT $ctid"; then
            output --ok "Started CT $ctid"
        fi
    elif (( ARG_STOP )); then
        if lx cmd --run "ssh $USER_PVE@$active_host pct stop $ctid" --log --log-tags "lxc,stop" --error-msg "Failed to stop CT $ctid"; then
            output --ok "Stopped CT $ctid"
        fi
    elif (( ARG_RESTART )); then
        if lx cmd --run "ssh $USER_PVE@$active_host pct restart $ctid" --log --log-tags "lxc,restart" --error-msg "Failed to restart CT $ctid"; then
            output --ok "Restarted CT $ctid"
        fi
    else
        output --error "No action specified. Use --start, --stop, or --restart."
    fi
}

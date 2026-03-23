#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container control
# Description: Manages the power state (Start, Stop, Restart) of an LXC container 
# by executing 'pct' commands via SSH on the active host.
# ==============================================================================

function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    # 1. Resolve State
    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"

    if [[ -z "$ctid" ]]; then
        output --error "Container ID required."
        return 1
    fi

    # 2. Execute Power Commands
    # We log the execution to the LPEX database for audit trails.
    if (( ARG_START )); then
        if lx cmd --run "ssh root@$active_host pct start $ctid" --log --log-tags "lxc,start" --error-msg "Failed to start CT $ctid"; then
            output --ok "Started CT $ctid"
        fi
    elif (( ARG_STOP )); then
        if lx cmd --run "ssh root@$active_host pct stop $ctid" --log --log-tags "lxc,stop" --error-msg "Failed to stop CT $ctid"; then
            output --ok "Stopped CT $ctid"
        fi
    elif (( ARG_RESTART )); then
        if lx cmd --run "ssh root@$active_host pct restart $ctid" --log --log-tags "lxc,restart" --error-msg "Failed to restart CT $ctid"; then
            output --ok "Restarted CT $ctid"
        fi
    else
        output --error "No action specified. Use --start, --stop, or --restart."
    fi
}

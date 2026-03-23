#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container ssh
# Description: Interactively attaches to an LXC container without requiring 
# an internal SSH daemon.
# ==============================================================================

function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"

    if [[ -z "$ctid" ]]; then
        output --error "Container ID required."
        return 1
    fi

    output --info "Attaching to Container $ctid on $active_host..."
    
    # We use 'ssh -t' to allocate a pseudo-TTY, enabling fully interactive 
    # terminal sessions inside the unprivileged container.
    ssh -t root@"$active_host" "pct enter $ctid"
}

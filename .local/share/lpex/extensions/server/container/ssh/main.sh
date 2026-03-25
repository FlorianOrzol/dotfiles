#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container ssh
# Description: Instantiates an interactive, pseudo-TTY shell session directly 
# inside an LXC container, bypassing the need for an internal SSH daemon.
# ==============================================================================

function extension_start() {
    
    enforce_config_var "USER_PVE"

    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]}"

    if [[ -z "$ctid" ]]; then
        output --error "Container ID required (--ctid)."
        return 1
    fi

    output --info "Establishing secure attachment to CT $ctid on $active_host..."
    
    # --- Feature: Pseudo-TTY Allocation ---
    # We pass the '-t' flag to SSH. This is critical because 'pct enter' requires 
    # a proper terminal interface (tty) to render interactive bash prompts correctly.
    ssh -t $USER_PVE@"$active_host" "pct enter $ctid"
}

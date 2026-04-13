#!/bin/bash
# ==============================================================================
# @meta_module      : server container ssh
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Opens an interactive shell inside a container via pct enter.
# @desc_detailed    : Connects to the active Proxmox host and attaches directly to the
# @desc_detailed    : container shell via pct enter. No SSH daemon required inside the
# @desc_detailed    : container. The -t flag allocates a PTY for correct terminal rendering.
#
# @arg_values       : --ctid | Target container ID (fzf-selectable)
#
# @exit_codes       : 0 | Session ended normally
# @exit_codes       : 1 | Missing ctid or SSH connection failure
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

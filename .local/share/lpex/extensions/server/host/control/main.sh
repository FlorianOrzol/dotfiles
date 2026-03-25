#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server host control
# Description: Orchestrates the physical power states of the Proxmox bare-metal 
# servers via SSH or IoT relays.
# ==============================================================================

function extension_start() {
    # --- 1. Infrastructure Validation ---
    enforce_config_var "USER_PVE"
    
    local node="${ARG_NODE[0]}"
    if [[ -z "$node" ]]; then
        output --error "Hardware Node Name required (--node)."
        return 1
    fi

    # ==========================================================================
    # --- Feature: Hardware Power Dispatcher ---
    # ==========================================================================
    if (( ARG_START )); then
        output --section "Hardware Wakeup: $node"
        output --warn "TODO: Implement Shelly REST API call here."
        
    elif (( ARG_STOP )); then
        output --section "Graceful Shutdown: $node"
        
        # --- Feature: Dynamic IP Resolution ---
        # Instead of hardcoded 'if pve102 then...', we construct the config variable 
        # name dynamically based on the user's input.
        local node_upper="${node^^}"
        local ip_var="IP_$node_upper"
        local ip="${!ip_var}"
        
        if [[ -z "$ip" ]]; then
            output --error "Failed to resolve IP for $node. Please define $ip_var in your config.conf."
            return 1
        fi
        
        # Send ACPI signal via authenticated SSH
        if lx cmd --run "ssh $USER_PVE@$ip 'shutdown -h now'" --log --log-tags "host,stop"; then
            output --ok "ACPI Shutdown signal successfully dispatched to $ip."
        fi
    else
        output --error "No action specified. Use --start or --stop."
    fi
}

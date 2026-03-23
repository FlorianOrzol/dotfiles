#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server host control
# Description: Manages the physical power state of Proxmox nodes.
# Includes Wake-on-LAN/Shelly for starting, and ACPI/SSH for soft shutdowns.
# ==============================================================================

function extension_start() {
    # 1. Resolve Target Node
    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    
    if [[ -z "$node" ]]; then
        output --error "Host node required (e.g. pve102)."
        return 1
    fi

    # 2. Execute Power State Change
    if (( ARG_START )); then
        output --section "Waking up $node"
        output --warn "TODO: Implement Shelly REST API call here."
        
    elif (( ARG_STOP )); then
        # IP Mapping (To be moved to a DB lookup in the future)
        local ip="10.0.101.1"
        [[ "$node" == "pve102" ]] && ip="10.0.102.1"
        [[ "$node" == "pve103" ]] && ip="10.0.103.1"
        
        output --section "Shutting down $node"
        
        # Execute soft shutdown and log to audit trail
        if lx cmd --run "ssh root@$ip 'shutdown -h now'" --log --log-tags "host,stop"; then
            output --ok "Shutdown signal successfully sent to $ip."
        fi
    else
        output --error "No action specified (--start, --stop)."
    fi
}

#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server host ssh
# Description: Instantiates an interactive SSH session to the Proxmox bare-metal host.
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_PVE"
    
    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    if [[ -z "$node" ]]; then
        output --error "Proxmox node required (--node)."
        return 1
    fi

    local node_upper="${node^^}"
    local ip_var="IP_${node_upper}"
    local ip="${!ip_var}"

    if [[ -z "$ip" ]]; then
        output --error "Failed to resolve IP for $node. Define $ip_var in config.conf."
        return 1
    fi

    output --info "Establishing secure attachment to $node ($ip)..."
    ssh "$USER_PVE@$ip"
}

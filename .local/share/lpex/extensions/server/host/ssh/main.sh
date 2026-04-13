#!/bin/bash
# ==============================================================================
# @meta_module      : server host ssh
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Opens an interactive SSH session to a Proxmox host.
# @desc_detailed    : Resolves the node's IP from config and connects via SSH.
# @desc_detailed    : Supports positional node name as fallback to --node flag.
#
# @arg_values       : --node | Target Proxmox node (pve101, pve102, pve103)
#
# @exit_codes       : 0 | Session ended normally
# @exit_codes       : 1 | Missing node or IP resolution failure
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

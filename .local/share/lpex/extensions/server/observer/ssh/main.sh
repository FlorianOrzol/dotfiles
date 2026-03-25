#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server observer ssh
# Description: Instantiates an interactive SSH session to the Observer node.
# ==============================================================================

function extension_start() {
    
    enforce_config_var "USER_OBSERVER"

    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    
    if [[ -z "$node" ]]; then
        output --error "Observer node required (--node)."
        return 1
    fi

    local ip=$(get_observer_ip "$node")
    [[ -z "$ip" ]] && { output --error "Unknown observer node: $node"; return 1; }

    output --info "Establishing secure attachment to $node ($ip)..."
    ssh $USER_OBSERVER@"$ip"
}

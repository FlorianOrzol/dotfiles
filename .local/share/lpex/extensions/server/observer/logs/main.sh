#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server observer logs
# Description: Streams the live system journalctl logs for a specific service.
# ==============================================================================

function extension_start() {
    
    enforce_config_var "USER_OBSERVER"

    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    local service_name="${ARG_NAME[0]:-${ARGS_EXTENSION_ARRAY[1]}}"

    if [[ -z "$node" || -z "$service_name" ]]; then
        output --error "Usage: lpex server observer logs --node <pi> --name <service>"
        return 1
    fi

    local ip=$(get_observer_ip "$node")
    output --section "Streaming Logs: $service_name on $node"
    
    # Follow mode (-f) requires a pseudo-tty (-t) to stream cleanly
    ssh -t $USER_OBSERVER@"$ip" "journalctl -u $service_name -f"
}

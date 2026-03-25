#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server host status
# Description: Fetches a lightning-fast health check from the Proxmox node,
# summarizing CPU load, RAM usage, and ZFS pool integrity.
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

    output --section "Host Health Check: $node ($ip)"
    
    # --- Feature: One-Shot Introspection ---
    # We query Uptime/Load, Memory, and ZFS status in a single SSH connection.
    local script="
        echo '--- LOAD ---'
        uptime
        echo '--- MEMORY ---'
        free -m | awk 'NR==2{printf \"RAM: %s MB used / %s MB total (%.2f%%)\\n\", \$3,\$2,\$3*100/\$2 }'
        echo '--- ZFS POOLS ---'
        if command -v zpool >/dev/null 2>&1; then
            zpool list -o name,size,alloc,free,frag,cap,health
        else
            echo 'ZFS not installed or accessible.'
        fi
    "

    output --info "Querying metrics..."
    local result
    result=$(ssh -o ConnectTimeout=2 "$USER_PVE@$ip" "$script" 2>/dev/null)

    if [[ -z "$result" ]]; then
        output --error "Node is unreachable or offline."
        return 1
    fi

    # Output formatting
    echo "$result" | while IFS= read -r line; do
        if [[ "$line" == "---"* ]]; then
            output --warn "\n${line//-/}"
        else
            output --ok "  $line"
        fi
    done
}

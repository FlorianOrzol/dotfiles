#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server observer status
# Description: Fetches the cluster HA state directly from the Observer's 
# database via SSH.
# ==============================================================================

function extension_start() {
    # --- 1. Environment Validation ---
    enforce_config_var "USER_OBSERVER"
    enforce_config_var "PATH_OBSERVER_DB"
    
    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    [[ -z "$node" ]] && node="pi1"
    
    local ip=$(get_observer_ip "$node")

    output --section "Observer Status: $node ($ip)"
    
    # --- Feature: Lightning Fast SSH Introspection ---
    # We execute a chained command utilizing the dynamic database path.
    output --info "Fetching database state..."
    local state_raw
    state_raw=$(ssh -o ConnectTimeout=2 $USER_OBSERVER@"$ip" "
        echo 'LEADER:'; cat $PATH_OBSERVER_DB/host_leader 2>/dev/null; echo '';
        echo 'OBSERVER:'; cat $PATH_OBSERVER_DB/observer_leader 2>/dev/null; echo '';
        echo 'CLIENTS:'; ls $PATH_OBSERVER_DB/clients 2>/dev/null
    " 2>/dev/null)

    if [[ -z "$state_raw" ]]; then
        output --error "Failed to read database at $PATH_OBSERVER_DB. Is the node offline?"
        return 1
    fi

    # Render output clearly
    echo "$state_raw" | while IFS= read -r line; do
        if [[ "$line" == *":"* ]]; then
            output --warn "\n$line"
        elif [[ -n "$line" ]]; then
            output --ok "  $line"
        fi
    done
}

#!/bin/bash
# ==============================================================================
# @meta_module      : server observer ssh
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Opens an interactive SSH session to an Observer Pi.
# @desc_detailed    : Resolves the node's IP via get_observer_ip and connects via SSH.
# @desc_detailed    : Supports positional node name as fallback to --node flag.
#
# @arg_values       : --node | Target Observer (pi1 or pi2)
#
# @exit_codes       : 0 | Session ended normally
# @exit_codes       : 1 | Missing node or unknown observer name
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
    ssh "$USER_OBSERVER@$ip"
}

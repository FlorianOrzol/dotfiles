#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server observer service
# Description: Controls global Systemd services on the Observer Pi using sudo.
# ==============================================================================

function extension_start() {
    
    enforce_config_var "USER_OBSERVER"

    local node="${ARG_NODE[0]}"
    local service_name="${ARG_NAME[0]}"

    if [[ -z "$node" || -z "$service_name" ]]; then
        output --error "Usage: lpex server observer service --node <pi> --name <service> [--start|--stop|...]"
        return 1
    fi

    local ip=$(get_observer_ip "$node")
    local action=""
    
    (( ARG_START )) && action="start"
    (( ARG_STOP )) && action="stop"
    (( ARG_RESTART )) && action="restart"
    (( ARG_ENABLE )) && action="enable"

    if [[ -z "$action" ]]; then
        output --error "Please specify an action (--start, --stop, --restart, --enable)."
        return 1
    fi

    output --info "Executing 'sudo systemctl $action $service_name' on $node..."
    
    # We use -t to allow the user to type the sudo password interactively
    if lx cmd --run "ssh -t $USER_OBSERVER@$ip 'sudo systemctl $action $service_name'"; then
        output --ok "Service $action successful."
    else
        output --error "Failed to $action service."
    fi
}

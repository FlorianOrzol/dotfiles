function extension_start() {
    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    
    if [[ -z "$node" ]]; then
        output --error "Host node required (e.g. pve102)."
        return 1
    fi

    if (( ARG_START )); then
        output --section "Waking up $node"
        output --warn "TODO: Implement Shelly REST API call here."
    elif (( ARG_STOP )); then
        local ip="10.0.101.1"
        [[ "$node" == "pve102" ]] && ip="10.0.102.1"
        [[ "$node" == "pve103" ]] && ip="10.0.103.1"
        
        output --section "Shutting down $node"
        if lx cmd --run "ssh root@$ip 'shutdown -h now'" --log --log-tags "host,stop"; then
            output --ok "Shutdown signal sent to $ip."
        fi
    else
        output --error "No action specified (--start, --stop)."
    fi
}

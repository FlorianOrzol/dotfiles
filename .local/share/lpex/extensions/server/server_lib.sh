#!/bin/bash

function get_active_host() {
    local ip
    ip=$(sqlite3 "$PATH_EXTENSION_DATA/config.db" "SELECT value FROM config WHERE key='active_host_ip';" 2>/dev/null)
    echo "${ip:-10.0.101.1}"
}

function get_lxc_completion_cmd() {
    echo "ssh -q -o ConnectTimeout=1 root@\$(sqlite3 ~/.local/state/lpex/data/server/config.db \"SELECT value FROM config WHERE key='active_host_ip';\" 2>/dev/null || echo 10.0.101.1) 'pct list | awk '\''NR>1 {print \$1 \" # \" \$3 \" - \" \$2}'\''' 2>/dev/null"
}

function ensure_payload_dir() {
    local payload_type="${1:-scripts}" # 'scripts' or 'configs'
    local target_type="${2:-global}"   # 'container', 'host', or 'global'
    local target_id="${3}"             # e.g., '1111'
    
    local dir_path="$PATH_EXTENSION_DATA/$target_type"
    
    if [[ "$target_type" != "global" ]]; then
        dir_path="$dir_path/$target_id/$payload_type"
    else
        dir_path="$dir_path/container/$payload_type"
    fi
    
    mkdir -p "$dir_path" 2>/dev/null
    echo "$dir_path"
}

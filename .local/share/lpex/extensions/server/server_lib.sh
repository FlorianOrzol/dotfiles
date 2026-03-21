#!/bin/bash
# ==============================================================================
# --- Server Extension Shared Library ---
# ==============================================================================

function get_active_host() {
    local ip
    ip=$(sqlite3 "$PATH_EXTENSION_DATA/config.db" "SELECT value FROM config WHERE key='active_host_ip';" 2>/dev/null)
    echo "${ip:-10.0.101.1}"
}

function get_lxc_completion_cmd() {
    echo "ssh -q -o ConnectTimeout=1 root@\$(sqlite3 ~/.local/state/lpex/data/server/config.db \"SELECT value FROM config WHERE key='active_host_ip';\" 2>/dev/null || echo 10.0.101.1) 'pct list | awk '\''NR>1 {print \$1 \" # \" \$3 \" - \" \$2}'\''' 2>/dev/null"
}

# Creates and returns a structured filesystem directory mirroring the remote tree.
function ensure_fs_dir() {
    local target_type="${1:-global}"   # 'container', 'host', or 'global'
    local target_id="${2}"             
    
    local dir_path="$PATH_EXTENSION_DATA/$target_type"
    
    if [[ "$target_type" != "global" ]]; then
        dir_path="$dir_path/$target_id/filesystem"
    else
        dir_path="$dir_path/container/filesystem"
    fi
    
    mkdir -p "$dir_path" 2>/dev/null
    echo "$dir_path"
}

function init_command_db() {
    local schema="id INTEGER PRIMARY KEY, target_type TEXT, target_id TEXT, alias TEXT, command TEXT, UNIQUE(target_type, target_id, alias)"
    lx db --file "commands.db" --table "device_commands" --create-table --cols "$schema" >/dev/null 2>&1 || true
}

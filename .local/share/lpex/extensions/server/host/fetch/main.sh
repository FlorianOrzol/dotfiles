#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server host fetch
# Description: Securely pulls files or entire directories from a Bare-Metal Host.
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_PVE"
    
    local node="${ARG_NODE[0]}"
    local remote_path="${ARG_REMOTE_FILE[0]}"

    if [[ -z "$node" || -z "$remote_path" || "$remote_path" != /* ]]; then
        output --error "Usage: lpex server host fetch --node <node> --remote-file <ABSOLUTE_PATH>"
        return 1
    fi

    local node_upper="${node^^}"
    local ip_var="IP_${node_upper}"
    local ip="${!ip_var}"
    [[ -z "$ip" ]] && { output --error "IP not found for $node."; return 1; }

    remote_path="${remote_path%/}"
    local fs_dir=$(ensure_fs_dir "host" "$node")
    local local_dest="$fs_dir/${remote_path#/}"
    
    local safe_name=$(basename "$remote_path")
    local tmp_tar="/tmp/lpex_fetch_${node}_${safe_name}.tar.gz"

    output --section "Fetching $remote_path from $node"
    
    local is_dir=0
    lx cmd --run "ssh $USER_PVE@$ip '[ -d \"$remote_path\" ]'" --quiet --no-error-msg && is_dir=1

    if (( is_dir )); then
        output --info "Target is a DIRECTORY. Packing..."
        lx cmd --run "ssh $USER_PVE@$ip 'cd \"$remote_path\" && tar -czf $tmp_tar .'" --quiet || return 1
        output --info "Downloading..."
        lx cmd --run "rsync -avz $USER_PVE@$ip:\"$tmp_tar\" /tmp/local.tar.gz" --quiet || return 1
        mkdir -p "$local_dest"
        tar -xzf /tmp/local.tar.gz -C "$local_dest"
        rm -f /tmp/local.tar.gz
        lx cmd --run "ssh $USER_PVE@$ip 'rm -f \"$tmp_tar\"'" --quiet
    else
        output --info "Target is a FILE. Downloading..."
        mkdir -p "$(dirname "$local_dest")"
        lx cmd --run "rsync -avz $USER_PVE@$ip:\"$remote_path\" \"$local_dest\"" --quiet || return 1
    fi
    output --ok "Successfully fetched to: $local_dest"
}

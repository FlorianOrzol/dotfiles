#!/bin/bash
# ==============================================================================
# @meta_module      : server host fetch
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Pulls files or directories from a Proxmox host into the local tree.
# @desc_detailed    : Mirrors the remote path structure locally. Directories are packed
# @desc_detailed    : into a tarball on the host and transferred via rsync. Single files
# @desc_detailed    : are fetched directly without a staging step.
#
# @arg_values       : --node        | Target Proxmox node (pve101, pve102, pve103)
# @arg_values       : --remote-file | Absolute path on the host to fetch
#
# @exit_codes       : 0 | Fetch completed, local tree updated
# @exit_codes       : 1 | Missing arguments, IP resolution failure, or transfer error
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
    local local_tar="/tmp/lpex_fetch_${node}_${safe_name}_local.tar.gz"

    output --section "Fetching $remote_path from $node"

    local is_dir=0
    lx cmd --run "ssh $USER_PVE@$ip '[ -d \"$remote_path\" ]'" --quiet --no-error-msg && is_dir=1

    if (( is_dir )); then
        output --info "Target is a DIRECTORY. Packing..."
        if ! lx cmd --run "ssh $USER_PVE@$ip 'cd \"$remote_path\" && tar -czf $tmp_tar .'" --quiet --error-msg "Tar creation failed"; then return 1; fi
        output --info "Downloading..."
        if ! lx cmd --run "rsync -avz $USER_PVE@$ip:\"$tmp_tar\" \"$local_tar\"" --quiet --error-msg "Rsync failed"; then return 1; fi
        mkdir -p "$local_dest"
        tar -xzf "$local_tar" -C "$local_dest"
        rm -f "$local_tar"
        lx cmd --run "ssh $USER_PVE@$ip 'rm -f \"$tmp_tar\"'" --quiet
    else
        output --info "Target is a FILE. Downloading..."
        mkdir -p "$(dirname "$local_dest")"
        lx cmd --run "rsync -avz $USER_PVE@$ip:\"$remote_path\" \"$local_dest\"" --quiet || return 1
    fi
    output --ok "Successfully fetched to: $local_dest"
}

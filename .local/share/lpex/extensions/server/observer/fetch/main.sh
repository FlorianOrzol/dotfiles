#!/bin/bash
# ==============================================================================
# @meta_module      : server observer fetch
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Pulls files or directories from an Observer Pi into the local tree.
# @desc_detailed    : Mirrors the remote path structure locally. Uses sudo for system
# @desc_detailed    : paths (/etc, /lib, ...). Directories are packed via sudo tar and
# @desc_detailed    : transferred via rsync. Single files are staged via sudo cp.
#
# @arg_values       : --node        | Target Observer (pi1 or pi2)
# @arg_values       : --remote-file | Absolute path on the Observer to fetch
#
# @exit_codes       : 0 | Fetch completed, local tree updated
# @exit_codes       : 1 | Missing arguments or transfer failure
# ==============================================================================

function extension_start() {
    # --- 1. Resolve Target ---
    enforce_config_var "USER_OBSERVER"
    
    local node="${ARG_NODE[0]}"
    local remote_path="${ARG_REMOTE_FILE[0]}"

    if [[ -z "$node" || -z "$remote_path" || "$remote_path" != /* ]]; then
        output --error "Usage: lpex server observer fetch --node <pi1|pi2> --remote-file <ABSOLUTE_PATH>"
        return 1
    fi

    local ip=$(get_observer_ip "$node")
    remote_path="${remote_path%/}" # Strip trailing slash

    # --- 2. Calculate Tree Mirroring Paths ---
    local fs_dir=$(ensure_fs_dir "observer" "$node")
    local relative_path="${remote_path#/}"
    local local_dest="$fs_dir/$relative_path"
    
    local safe_name=$(basename "$remote_path")
    local tmp_host_tar="/tmp/lpex_fetch_${node}_${safe_name}.tar.gz"
    local local_tar="/tmp/lpex_fetch_local.tar.gz"

    output --section "Fetching $remote_path from $node"
    
    # --- 3. Introspect Remote Target (Requires sudo for system paths) ---
    local is_dir=0
    if lx cmd --run "ssh $USER_OBSERVER@$ip 'sudo [ -d \"$remote_path\" ]'" --quiet --no-error-msg; then
        is_dir=1
    fi

    # ==========================================================================
    # --- Feature: Tar-Pipe Extraction (For Directories) ---
    # ==========================================================================
    if (( is_dir )); then
        output --info "Target is a DIRECTORY. Packing into tarball via sudo..."
        
        if ! lx cmd --run "ssh -t $USER_OBSERVER@$ip 'sudo bash -c \"cd \\\"$remote_path\\\" && tar -czf $tmp_host_tar .\"'" --quiet --error-msg "Tar creation failed"; then return 1; fi
        
        # We must chown the tarball so fadmin can rsync it without sudo
        lx cmd --run "ssh $USER_OBSERVER@$ip 'sudo chown $USER_OBSERVER:$USER_OBSERVER $tmp_host_tar'" --quiet
        
        output --info "Downloading to Desktop..."
        if ! lx cmd --run "rsync -avz $USER_OBSERVER@$ip:\"$tmp_host_tar\" \"$local_tar\"" --quiet --error-msg "Rsync failed"; then return 1; fi
        
        output --info "Unpacking into local filesystem..."
        mkdir -p "$local_dest"
        tar -xzf "$local_tar" -C "$local_dest"
        rm -f "$local_tar"
        
        lx cmd --run "ssh $USER_OBSERVER@$ip 'sudo rm -f \"$tmp_host_tar\"'" --quiet
    
    # ==========================================================================
    # --- Feature: Direct Pull (For Single Files) ---
    # ==========================================================================
    else
        output --info "Target is a FILE. Staging via sudo..."
        mkdir -p "$(dirname "$local_dest")"
        
        # We copy to tmp and chown to ensure we can read files like /etc/shadow if requested
        if ! lx cmd --run "ssh -t $USER_OBSERVER@$ip 'sudo cp \"$remote_path\" \"$tmp_host_tar\" && sudo chown $USER_OBSERVER:$USER_OBSERVER \"$tmp_host_tar\"'" --quiet --error-msg "Staging failed"; then return 1; fi
        
        output --info "Downloading..."
        if ! lx cmd --run "rsync -avz $USER_OBSERVER@$ip:\"$tmp_host_tar\" \"$local_dest\"" --quiet --error-msg "Rsync failed"; then return 1; fi
        
        lx cmd --run "ssh $USER_OBSERVER@$ip 'sudo rm -f \"$tmp_host_tar\"'" --quiet
    fi

    output --ok "Successfully fetched to: $local_dest"
}

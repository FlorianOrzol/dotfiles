#!/bin/bash
# ==============================================================================
# @meta_module      : server container fetch
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Pulls files or directories from a container into the local tree.
# @desc_detailed    : Mirrors the remote path structure locally. For directories, uses
# @desc_detailed    : a tar-pipe via pct pull since pct pull does not support folders.
# @desc_detailed    : Single files are pulled directly via pct pull + rsync.
#
# @arg_values       : --ctid        | Target container ID (fzf-selectable)
# @arg_values       : --remote-file | Absolute path on the container to fetch
#
# @exit_codes       : 0 | Fetch completed, local tree updated
# @exit_codes       : 1 | Missing arguments or transfer failure
# ==============================================================================

function extension_start() {
    
    # --- 1. Resolve Target ---
    enforce_config_var "USER_PVE"

    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]}"
    local remote_path="${ARG_REMOTE_FILE[0]}"

    if [[ -z "$ctid" || -z "$remote_path" || "$remote_path" != /* ]]; then
        output --error "Usage: lpex server container fetch --ctid <ID> --remote-file <ABSOLUTE_PATH>"
        return 1
    fi

    # Strip trailing slash from input to ensure path calculation remains predictable
    remote_path="${remote_path%/}"

    # --- 2. Calculate Tree Mirroring Paths ---
    # We dynamically build the local directory tree to exactly match the remote structure.
    local fs_dir=$(ensure_fs_dir "container" "$ctid")
    local relative_path="${remote_path#/}"
    local local_dest="$fs_dir/$relative_path"
    
    # Define temporary staging paths for the host and local machine
    local safe_name=$(basename "$remote_path")
    local tmp_host_tar="/tmp/lpex_fetch_${ctid}_${safe_name}.tar.gz"
    local local_tar="/tmp/lpex_fetch_local.tar.gz"

    output --section "Fetching $remote_path from CT $ctid"
    
    # --- 3. Introspect Remote Target ---
    # We must determine if the target is a file or a directory to choose the right extraction method.
    local is_dir=0
    if lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- [ -d \"$remote_path\" ]'" --quiet --no-error-msg; then
        is_dir=1
    fi

    # ==========================================================================
    # --- Feature: Tar-Pipe Extraction (For Directories) ---
    # Because 'pct pull' strictly fails on directories, we pack the folder into
    # a tarball *inside* the container, pull the tarball, and unpack it locally.
    # ==========================================================================
    if (( is_dir )); then
        output --info "Target is a DIRECTORY. Packing into tarball..."
        
        # Step A: Pack inside container
        if ! lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- bash -c \"cd \\\"$remote_path\\\" && tar -czf /tmp/fetch.tar.gz .\"'" --quiet --error-msg "Tar creation failed"; then return 1; fi
        
        # Step B: Pull tarball through the Proxmox firewall
        output --info "Extracting tarball from Container (pct pull)..."
        if ! lx cmd --run "ssh $USER_PVE@$active_host 'pct pull $ctid /tmp/fetch.tar.gz \"$tmp_host_tar\"'" --quiet --error-msg "pct pull failed"; then return 1; fi
        
        # Step C: Transport to Desktop
        output --info "Downloading to Desktop..."
        if ! lx cmd --run "rsync -avz $USER_PVE@$active_host:\"$tmp_host_tar\" \"$local_tar\"" --quiet --error-msg "Rsync failed"; then return 1; fi
        
        # Step D: Unpack and destroy evidence
        output --info "Unpacking into local filesystem..."
        mkdir -p "$local_dest"
        tar -xzf "$local_tar" -C "$local_dest"
        rm -f "$local_tar"
        
        lx cmd --run "ssh $USER_PVE@$active_host 'rm -f \"$tmp_host_tar\"; pct exec $ctid -- rm -f /tmp/fetch.tar.gz'" --quiet
    
    # ==========================================================================
    # --- Feature: Direct Pull (For Single Files) ---
    # ==========================================================================
    else
        output --info "Target is a FILE. Pulling directly..."
        mkdir -p "$(dirname "$local_dest")"
        
        if ! lx cmd --run "ssh $USER_PVE@$active_host 'pct pull $ctid \"$remote_path\" \"$tmp_host_tar\"'" --quiet --error-msg "pct pull failed"; then return 1; fi
        if ! lx cmd --run "rsync -avz $USER_PVE@$active_host:\"$tmp_host_tar\" \"$local_dest\"" --quiet --error-msg "Rsync failed"; then return 1; fi
        
        lx cmd --run "ssh $USER_PVE@$active_host 'rm -f \"$tmp_host_tar\"'" --quiet
    fi

    output --ok "Successfully fetched to: $local_dest"
}

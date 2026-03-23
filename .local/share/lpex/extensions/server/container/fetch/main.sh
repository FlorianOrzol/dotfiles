#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container fetch
# Description: Securely pulls configuration files or entire directories out of 
# unprivileged containers using a 'Tar-Pipe' architecture.
# ==============================================================================

function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    # 1. Resolve Target
    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    local remote_path="${ARG_REMOTE_FILE[0]:-${ARGS_EXTENSION_ARRAY[1]}}"

    if [[ -z "$ctid" || -z "$remote_path" || "$remote_path" != /* ]]; then
        output --error "Usage: lpex server container fetch <CTID> <ABSOLUTE_PATH>"
        return 1
    fi

    # Strip trailing slash to keep naming logic consistent
    remote_path="${remote_path%/}"

    # 2. Prepare Local Paths (Tree Mirroring)
    local fs_dir=$(ensure_fs_dir "container" "$ctid")
    local relative_path="${remote_path#/}"
    local local_dest="$fs_dir/$relative_path"
    
    local safe_name=$(basename "$remote_path")
    local tmp_host_tar="/tmp/lpex_fetch_${ctid}_${safe_name}.tar.gz"
    local local_tar="/tmp/lpex_fetch_local.tar.gz"

    output --section "Fetching $remote_path from CT $ctid"
    
    # 3. Determine Remote Type (File or Directory)
    local is_dir=0
    if lx cmd --run "ssh root@$active_host 'pct exec $ctid -- [ -d \"$remote_path\" ]'" --quiet --no-error-msg; then
        is_dir=1
    fi

    # 4. Execution Pipeline
    if (( is_dir )); then
        output --info "Target is a DIRECTORY. Packing into tarball..."
        
        # Step 4a: Pack inside container
        if ! lx cmd --run "ssh root@$active_host 'pct exec $ctid -- bash -c \"cd \\\"$remote_path\\\" && tar -czf /tmp/fetch.tar.gz .\"'" --quiet --error-msg "Tar creation failed"; then return 1; fi
        
        # Step 4b: Extract from container to host via pct pull
        output --info "Extracting tarball from Container (pct pull)..."
        if ! lx cmd --run "ssh root@$active_host 'pct pull $ctid /tmp/fetch.tar.gz \"$tmp_host_tar\"'" --quiet --error-msg "pct pull failed"; then return 1; fi
        
        # Step 4c: Download to desktop
        output --info "Downloading to Desktop..."
        if ! lx cmd --run "rsync -avz root@$active_host:\"$tmp_host_tar\" \"$local_tar\"" --quiet --error-msg "Rsync failed"; then return 1; fi
        
        # Step 4d: Unpack and cleanup
        output --info "Unpacking into local filesystem..."
        mkdir -p "$local_dest"
        tar -xzf "$local_tar" -C "$local_dest"
        rm -f "$local_tar"
        lx cmd --run "ssh root@$active_host 'rm -f \"$tmp_host_tar\"; pct exec $ctid -- rm -f /tmp/fetch.tar.gz'" --quiet
    else
        output --info "Target is a FILE. Pulling directly..."
        mkdir -p "$(dirname "$local_dest")"
        
        if ! lx cmd --run "ssh root@$active_host 'pct pull $ctid \"$remote_path\" \"$tmp_host_tar\"'" --quiet --error-msg "pct pull failed"; then return 1; fi
        if ! lx cmd --run "rsync -avz root@$active_host:\"$tmp_host_tar\" \"$local_dest\"" --quiet --error-msg "Rsync failed"; then return 1; fi
        
        lx cmd --run "ssh root@$active_host 'rm -f \"$tmp_host_tar\"'" --quiet
    fi

    output --ok "Successfully fetched to: $local_dest"
}

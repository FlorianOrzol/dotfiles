#!/bin/bash
function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    local remote_path="${ARG_REMOTE_FILE[0]:-${ARGS_EXTENSION_ARRAY[1]}}"

    if [[ -z "$ctid" || -z "$remote_path" || "$remote_path" != /* ]]; then
        output --error "Usage: lpex server container fetch --ctid <ID> --remote-file <ABSOLUTE_PATH>"
        return 1
    fi

    # Strip trailing slash from remote path if present to keep naming consistent
    remote_path="${remote_path%/}"

    local fs_dir=$(ensure_fs_dir "container" "$ctid")
    local relative_path="${remote_path#/}"
    local local_dest="$fs_dir/$relative_path"
    
    local safe_name=$(basename "$remote_path")
    local tmp_host_tar="/tmp/lpex_fetch_${ctid}_${safe_name}.tar.gz"
    local local_tar="/tmp/lpex_fetch_local.tar.gz"

    # Check if the remote path is a directory or a file
    output --section "Fetching $remote_path from CT $ctid"
    output --info "Checking remote type..."
    
    local is_dir=0
    if lx cmd --run "ssh root@$active_host 'pct exec $ctid -- [ -d \"$remote_path\" ]'" --quiet --no-error-msg; then
        is_dir=1
    fi

    if (( is_dir )); then
        output --info "Target is a DIRECTORY. Packing into tarball..."
        # Pack the directory contents inside the container
        if ! lx cmd --run "ssh root@$active_host 'pct exec $ctid -- bash -c \"cd \\\"$remote_path\\\" && tar -czf /tmp/fetch.tar.gz .\"'" --quiet --error-msg "Tar creation failed in container"; then return 1; fi
        
        output --info "Extracting tarball from Container (pct pull)..."
        if ! lx cmd --run "ssh root@$active_host 'pct pull $ctid /tmp/fetch.tar.gz \"$tmp_host_tar\"'" --quiet --error-msg "pct pull failed"; then return 1; fi
        
        output --info "Downloading to Desktop..."
        if ! lx cmd --run "rsync -avz root@$active_host:\"$tmp_host_tar\" \"$local_tar\"" --quiet --error-msg "Rsync failed"; then return 1; fi
        
        output --info "Unpacking into local filesystem..."
        mkdir -p "$local_dest"
        tar -xzf "$local_tar" -C "$local_dest"
        rm -f "$local_tar"
        
        # Cleanup container and host
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

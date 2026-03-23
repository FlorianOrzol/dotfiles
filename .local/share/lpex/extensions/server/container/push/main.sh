#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container push
# Description: Pushes files or directories from the local 'Tree Mirror' back 
# into the unprivileged container. Auto-calculates remote destinations.
# ==============================================================================

function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    # 1. Resolve Targets
    local active_host=$(get_active_host)
    local target_ctids=("${ARG_CTID[@]}")
    local local_paths=("${ARG_LOCAL_FILE[@]}")

    if [[ ${#target_ctids[@]} -eq 0 || ${#local_paths[@]} -eq 0 ]]; then
        output --error "Usage: lpex server container push <CTID> <relative/path>"
        return 1
    fi

    local global_dir=$(ensure_fs_dir "global")

    # 2. Iterate Target Containers
    for ctid in "${target_ctids[@]}"; do
        output --section "Pushing to CT $ctid"
        local specific_dir=$(ensure_fs_dir "container" "$ctid")
        
        # 3. Iterate Payload Paths
        for file_path in "${local_paths[@]}"; do
            output --info "Preparing: $file_path"
            file_path="${file_path%/}" # Strip trailing slash
            
            local abs_file=""
            
            # --- The Magic: Auto-calculate Remote Dest ---
            # Prepending a slash turns the local tree path into the absolute remote path
            local remote_dest="/${file_path#/}"
            
            # --- Priority Shadowing Logic ---
            if [[ "$file_path" == /* ]] && [[ -e "$file_path" ]]; then
                output --error "Please use relative paths from the local filesystem."
                continue
            elif [[ -e "$specific_dir/$file_path" ]]; then
                abs_file="$(realpath "$specific_dir/$file_path")"
                output --info "Using container-specific path."
            elif [[ -e "$global_dir/$file_path" ]]; then
                abs_file="$(realpath "$global_dir/$file_path")"
                output --info "Using global path pool."
            else
                output --error "Path not found: $file_path"
                continue
            fi

            local safe_name=$(basename "$abs_file")
            
            # 4. Pipeline Execution (File vs Directory)
            if [[ -d "$abs_file" ]]; then
                output --info "Target is a DIRECTORY. Packing tarball..."
                local local_tar="/tmp/lpex_push_local.tar.gz"
                tar -czf "$local_tar" -C "$abs_file" .
                
                output --info "-> Uploading Tarball to Host /tmp..."
                if ! lx cmd --run "rsync -avz '$local_tar' root@$active_host:/tmp/$safe_name.tar.gz" --quiet --error-msg "Rsync failed"; then continue; fi
                
                output --info "-> Injecting into Container..."
                if ! lx cmd --run "ssh root@$active_host 'pct push $ctid /tmp/$safe_name.tar.gz /tmp/$safe_name.tar.gz'" --quiet; then
                    output --error "pct push failed."
                    continue
                fi
                
                output --info "-> Extracting in Container at $remote_dest..."
                lx cmd --run "ssh root@$active_host 'pct exec $ctid -- bash -c \"mkdir -p \\\"$remote_dest\\\" && tar -xzf /tmp/$safe_name.tar.gz -C \\\"$remote_dest\\\"\"'" --quiet
                
                # Cleanup
                rm -f "$local_tar"
                lx cmd --run "ssh root@$active_host 'rm -f /tmp/$safe_name.tar.gz; pct exec $ctid -- rm -f /tmp/$safe_name.tar.gz'" --quiet
                
                output --ok "Success: Directory pushed to $remote_dest"
            else
                output --info "Target is a FILE."
                output --info "-> Uploading to Host /tmp..."
                if ! lx cmd --run "rsync -avz '$abs_file' root@$active_host:/tmp/$safe_name" --quiet --error-msg "Rsync failed"; then continue; fi

                # Ensure remote parent directory exists
                local remote_parent=$(dirname "$remote_dest")
                lx cmd --run "ssh root@$active_host 'pct exec $ctid -- mkdir -p \"$remote_parent\"'" --quiet

                output --info "-> Injecting into Container ($remote_dest)..."
                if lx cmd --run "ssh root@$active_host 'pct push $ctid /tmp/$safe_name \"$remote_dest\"'" --quiet; then
                    output --ok "Success: File pushed to $remote_dest"
                else
                    output --error "pct push failed."
                fi
                
                lx cmd --run "ssh root@$active_host 'rm -f /tmp/$safe_name'" --quiet
            fi
        done
    done
}

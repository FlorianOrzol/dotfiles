#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container push
# Description: Compiles local modifications from the 'Tree Mirror' and violently
# injects them back into the unprivileged container's filesystem.
# ==============================================================================

function extension_start() {
    
    # --- 1. Resolve Pipeline Requirements ---
    enforce_config_var "USER_PVE"

    local active_host=$(get_active_host)
    local target_ctids=("${ARG_CTID[@]}")
    local local_paths=("${ARG_LOCAL_FILE[@]}")

    if [[ ${#target_ctids[@]} -eq 0 || ${#local_paths[@]} -eq 0 ]]; then
        output --error "Usage: lpex server container push --ctid <ID> --local-file <relative/path>"
        return 1
    fi

    local global_dir=$(ensure_fs_dir "global")

    # ==========================================================================
    # --- Feature: Multi-Target Dispatcher ---
    # Allows rolling out a single configuration file to multiple containers
    # sequentially.
    # ==========================================================================
    for ctid in "${target_ctids[@]}"; do
        output --section "Pushing to CT $ctid"
        local specific_dir=$(ensure_fs_dir "container" "$ctid")
        
        for file_path in "${local_paths[@]}"; do
            output --info "Preparing: $file_path"
            
            # Normalize the path for calculation
            file_path="${file_path%/}" 
            
            local abs_file=""
            
            # --- Feature: Auto-calculated Destinations ---
            # By enforcing a strict mirror tree locally, we mathematically deduce 
            # the exact remote destination by simply prepending a root slash.
            local remote_dest="/${file_path#/}"
            
            # Priority Shadowing: Container-specific configs override global ones
            if [[ "$file_path" == /* ]] && [[ -e "$file_path" ]]; then
                output --error "Please use relative paths mapped from the local filesystem."
                continue
            elif [[ -e "$specific_dir/$file_path" ]]; then
                abs_file="$(realpath "$specific_dir/$file_path")"
                output --info "Matched container-specific path."
            elif [[ -e "$global_dir/$file_path" ]]; then
                abs_file="$(realpath "$global_dir/$file_path")"
                output --info "Matched global fallback pool."
            else
                output --error "Path not found in database: $file_path"
                continue
            fi

            local safe_name=$(basename "$abs_file")
            
            # ==================================================================
            # --- Feature: Injection Tar-Pipe (For Directories) ---
            # ==================================================================
            if [[ -d "$abs_file" ]]; then
                output --info "Target is a DIRECTORY. Assembling Tar-Pipe..."
                local local_tar="/tmp/lpex_push_local.tar.gz"
                
                # We package the *contents* of the directory, not the folder itself,
                # to allow clean overwrites into existing remote directories.
                tar -czf "$local_tar" -C "$abs_file" .
                
                output --info "-> Staging Tarball on Host /tmp..."
                if ! lx cmd --run "rsync -avz '$local_tar' $USER_PVE@$active_host:/tmp/$safe_name.tar.gz" --quiet --error-msg "Rsync failed"; then continue; fi
                
                output --info "-> Injecting into Container Perimeter..."
                if ! lx cmd --run "ssh $USER_PVE@$active_host 'pct push $ctid /tmp/$safe_name.tar.gz /tmp/$safe_name.tar.gz'" --quiet; then
                    output --error "pct push failed."
                    continue
                fi
                
                output --info "-> Detonating Archive at $remote_dest..."
                lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- bash -c \"mkdir -p \\\"$remote_dest\\\" && tar -xzf /tmp/$safe_name.tar.gz -C \\\"$remote_dest\\\"\"'" --quiet
                
                # Sanitize the battlefield
                rm -f "$local_tar"
                lx cmd --run "ssh $USER_PVE@$active_host 'rm -f /tmp/$safe_name.tar.gz; pct exec $ctid -- rm -f /tmp/$safe_name.tar.gz'" --quiet
                
                output --ok "Success: Directory securely pushed."
            
            # ==================================================================
            # --- Feature: Direct Injection (For Single Files) ---
            # ==================================================================
            else
                output --info "Target is a FILE. Initiating direct transfer..."
                output --info "-> Staging on Host /tmp..."
                if ! lx cmd --run "rsync -avz '$abs_file' $USER_PVE@$active_host:/tmp/$safe_name" --quiet --error-msg "Rsync failed"; then continue; fi

                # Pre-flight check: Ensure the remote architecture can receive the file
                local remote_parent=$(dirname "$remote_dest")
                lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- mkdir -p \"$remote_parent\"'" --quiet

                output --info "-> Injecting into Container ($remote_dest)..."
                if lx cmd --run "ssh $USER_PVE@$active_host 'pct push $ctid /tmp/$safe_name \"$remote_dest\"'" --quiet; then
                    output --ok "Success: File written."
                else
                    output --error "pct push failed."
                fi
                
                lx cmd --run "ssh $USER_PVE@$active_host 'rm -f /tmp/$safe_name'" --quiet
            fi
        done
    done
}

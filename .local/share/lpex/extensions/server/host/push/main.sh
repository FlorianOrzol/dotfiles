#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server host push
# Description: Compiles local modifications from the 'Tree Mirror' and violently
# injects them back into the Host's filesystem.
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_PVE"
    
    local target_nodes=("${ARG_NODE[@]}")
    local local_paths=("${ARG_LOCAL_FILE[@]}")

    if [[ ${#target_nodes[@]} -eq 0 || ${#local_paths[@]} -eq 0 ]]; then
        output --error "Usage: lpex server host push --node <node> --local-file <relative/path>"
        return 1
    fi

    local global_dir=$(ensure_fs_dir "global" "host")

    for node in "${target_nodes[@]}"; do
        output --section "Pushing to Host $node"
        
        local node_upper="${node^^}"
        local ip_var="IP_${node_upper}"
        local ip="${!ip_var}"
        [[ -z "$ip" ]] && { output --error "IP not found for $node."; continue; }
        
        local specific_dir=$(ensure_fs_dir "host" "$node")
        
        for file_path in "${local_paths[@]}"; do
            output --info "Preparing: $file_path"
            file_path="${file_path%/}" 
            
            local abs_file=""
            local remote_dest="/${file_path#/}"
            
            if [[ "$file_path" == /* ]] && [[ -e "$file_path" ]]; then
                output --error "Please use relative paths mapped from the local filesystem."
                continue
            elif [[ -e "$specific_dir/$file_path" ]]; then
                abs_file="$(realpath "$specific_dir/$file_path")"
                output --info "Matched node-specific path."
            elif [[ -e "$global_dir/$file_path" ]]; then
                abs_file="$(realpath "$global_dir/$file_path")"
                output --info "Matched global fallback pool."
            else
                output --error "Path not found in database: $file_path"
                continue
            fi

            local safe_name=$(basename "$abs_file")
            
            if [[ -d "$abs_file" ]]; then
                output --info "Target is a DIRECTORY. Assembling Tar-Pipe..."
                local local_tar="/tmp/lpex_push_local.tar.gz"
                
                tar -czf "$local_tar" -C "$abs_file" .
                
                output --info "-> Staging Tarball..."
                if ! lx cmd --run "rsync -avz '$local_tar' $USER_PVE@$ip:/tmp/$safe_name.tar.gz" --quiet --error-msg "Rsync failed"; then continue; fi
                
                output --info "-> Detonating Archive at $remote_dest..."
                lx cmd --run "ssh $USER_PVE@$ip 'mkdir -p \"$remote_dest\" && tar -xzf /tmp/$safe_name.tar.gz -C \"$remote_dest\"'" --quiet
                
                rm -f "$local_tar"
                lx cmd --run "ssh $USER_PVE@$ip 'rm -f /tmp/$safe_name.tar.gz'" --quiet
                
                output --ok "Success: Directory securely pushed."
            else
                output --info "Target is a FILE. Initiating direct transfer..."
                
                local remote_parent=$(dirname "$remote_dest")
                lx cmd --run "ssh $USER_PVE@$ip 'mkdir -p \"$remote_parent\"'" --quiet

                if lx cmd --run "rsync -avz '$abs_file' $USER_PVE@$ip:\"$remote_dest\"" --quiet; then
                    output --ok "Success: File written."
                else
                    output --error "Rsync push failed."
                fi
            fi
        done
    done
}

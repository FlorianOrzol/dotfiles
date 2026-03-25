#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server observer push
# Description: Deploys scripts and Systemd services to the Observer.
# ==============================================================================

function extension_start() {
    # --- 1. Environment Validation ---
    enforce_config_var "USER_OBSERVER"
    enforce_config_var "PATH_OBSERVER_SCRIPTS"
    enforce_config_var "PATH_OBSERVER_SYSTEMD"
    
    local node="${ARG_NODE[0]}"
    local local_paths=("${ARG_LOCAL_FILE[@]}")

    if [[ -z "$node" || ${#local_paths[@]} -eq 0 ]]; then
        output --error "Usage: lpex server observer push --node <pi1|pi2> --local-file <path>"
        return 1
    fi

    local ip=$(get_observer_ip "$node")
    local payload_dir="$PATH_EXTENSION_DATA/global/observer"

    output --section "Deploying to Observer: $node"

    for file_path in "${local_paths[@]}"; do
        local abs_file="$payload_dir/$file_path"
        [[ ! -f "$abs_file" ]] && { output --error "File not found: $abs_file"; continue; }

        output --info "Preparing: $file_path"
        
        # --- Feature: System Routing ---
        local is_service=0
        local remote_tmp="/tmp/$(basename "$file_path")"
        
        # Default destination: Scripts folder
        local final_dest="$PATH_OBSERVER_SCRIPTS/$(basename "$file_path")"

        if [[ "$file_path" == *.service || "$file_path" == *.timer ]]; then
            # Override destination: Systemd folder
            final_dest="$PATH_OBSERVER_SYSTEMD/$(basename "$file_path")"
            is_service=1
        fi

        output --info "-> Transferring to $final_dest"
        
        # Step 1: Push to tmp (Using standard SSH/Rsync)
        if ! lx cmd --run "rsync -avz '$abs_file' $USER_OBSERVER@$ip:'$remote_tmp'" --quiet; then
            output --error "Failed to transfer file."
            continue
        fi
            
        # Step 2: Elevate privileges to move file into protected system paths
        if (( is_service )); then
            output --info "-> Moving to systemd (Password may be required)..."
            # -t forces TTY allocation so sudo can prompt for the user's password interactively
            lx cmd --run "ssh -t $USER_OBSERVER@$ip 'sudo mv $remote_tmp $final_dest && sudo systemctl daemon-reload'"
        else
            # Scripts usually don't require sudo if the target directory is owned by the user
            lx cmd --run "ssh $USER_OBSERVER@$ip 'mkdir -p $PATH_OBSERVER_SCRIPTS && mv $remote_tmp $final_dest'" --quiet
        fi
        
        output --ok "Success: Deployment complete."
    done
}

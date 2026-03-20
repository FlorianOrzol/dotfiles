function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    local active_host=$(get_active_host)
    
    # Load all provided CTIDs and Scripts into arrays
    local target_ctids=("${ARG_CTID[@]}")
    local target_scripts=("${ARG_SCRIPT[@]}")

    if [[ ${#target_ctids[@]} -eq 0 || ${#target_scripts[@]} -eq 0 ]]; then
        output --error "Usage: lpex server container deploy --ctid <ID1> [--ctid <ID2>] --script <file1> [--script <file2>]"
        return 1
    fi

    local global_dir=$(ensure_payload_dir "scripts" "global")

    # Outer Loop: Containers
    for ctid in "${target_ctids[@]}"; do
        output --section "Deployment Target: CT $ctid"
        local specific_dir=$(ensure_payload_dir "scripts" "container" "$ctid")
        
        # Inner Loop: Scripts
        for script_path in "${target_scripts[@]}"; do
            output --info "Preparing script: $script_path"
            local abs_script=""
            
            # Resolution Priority:
            # 1. Absolute Path on local machine
            if [[ "$script_path" == /* ]] && [[ -f "$script_path" ]]; then
                abs_script="$script_path"
            # 2. Container-Specific Script
            elif [[ -f "$specific_dir/$script_path" ]]; then
                abs_script="$(realpath "$specific_dir/$script_path")"
            # 3. Global Script Pool
            elif [[ -f "$global_dir/$script_path" ]]; then
                abs_script="$(realpath "$global_dir/$script_path")"
            else
                output --error "Script not found: $script_path (Checked Absolute, Specific, and Global)"
                continue # Skip this script, but continue with others
            fi

            local script_name=$(basename "$abs_script")
            
            output --info "-> Uploading to Host..."
            if ! lx cmd --run "rsync -avz '$abs_script' root@$active_host:/tmp/$script_name" --quiet --error-msg "Rsync failed"; then continue; fi

            output --info "-> Injecting into Container..."
            if ! lx cmd --run "ssh root@$active_host 'pct push $ctid /tmp/$script_name /tmp/$script_name'" --quiet --error-msg "Injection failed"; then continue; fi
            
            output --info "-> Executing script..."
            lx cmd --run "ssh root@$active_host 'pct exec $ctid -- bash /tmp/$script_name'" --log --log-tags "deploy,$script_name"

            output --info "-> Cleaning up..."
            lx cmd --run "ssh root@$active_host 'rm -f /tmp/$script_name; pct exec $ctid -- rm -f /tmp/$script_name'" --quiet

            output --ok "Done: $script_name on CT $ctid"
        done
    done
    output --section "All Deployments Finished"
}

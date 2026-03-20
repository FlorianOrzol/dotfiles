function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    local active_host=$(get_active_host)
    
    local target_ctids=("${ARG_CTID[@]}")
    local local_files=("${ARG_LOCAL_FILE[@]}")
    local remote_dest="${ARG_REMOTE_DEST[0]}"

    if [[ ${#target_ctids[@]} -eq 0 || ${#local_files[@]} -eq 0 || -z "$remote_dest" ]]; then
        output --error "Usage: lpex server container push --ctid <ID> --local-file <file> --remote-dest <path>"
        return 1
    fi

    local global_dir=$(ensure_payload_dir "configs" "global")

    for ctid in "${target_ctids[@]}"; do
        output --section "Pushing to CT $ctid"
        local specific_dir=$(ensure_payload_dir "configs" "container" "$ctid")
        
        for file_path in "${local_files[@]}"; do
            output --info "Preparing config: $file_path"
            local abs_file=""
            
            if [[ "$file_path" == /* ]] && [[ -f "$file_path" ]]; then
                abs_file="$file_path"
            elif [[ -f "$specific_dir/$file_path" ]]; then
                abs_file="$(realpath "$specific_dir/$file_path")"
            elif [[ -f "$global_dir/$file_path" ]]; then
                abs_file="$(realpath "$global_dir/$file_path")"
            else
                output --error "Config file not found: $file_path"
                continue
            fi

            local file_name=$(basename "$abs_file")
            
            local final_dest="$remote_dest"
            if (( ${#local_files[@]} > 1 )); then
                [[ "$final_dest" != */ ]] && final_dest="$final_dest/"
                final_dest="$final_dest$file_name"
            fi
            
            output --info "-> Uploading to Host /tmp..."
            if ! lx cmd --run "rsync -avz '$abs_file' root@$active_host:/tmp/$file_name" --quiet --error-msg "Rsync failed"; then continue; fi

            output --info "-> Injecting into Container ($final_dest)..."
            if lx cmd --run "ssh root@$active_host 'pct push $ctid /tmp/$file_name \"$final_dest\"'" --quiet; then
                output --ok "Success: $file_name -> $final_dest"
            else
                output --error "pct push failed. Check remote path."
            fi
            
            lx cmd --run "ssh root@$active_host 'rm -f /tmp/$file_name'" --quiet
        done
    done
}

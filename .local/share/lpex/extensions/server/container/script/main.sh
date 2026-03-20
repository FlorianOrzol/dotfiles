function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    local is_global=${ARG_GLOBAL:-0}
    
    if [[ -z "$ctid" ]] && (( ! is_global )); then
        output --error "Please specify a Container ID or use --global."
        return 1
    fi
    
    local script_dir
    if (( is_global )); then
        script_dir=$(ensure_payload_dir "scripts" "global")
        output --info "Target: Global Script Pool"
    else
        script_dir=$(ensure_payload_dir "scripts" "container" "$ctid")
        output --info "Target: Container $ctid Scripts"
    fi
    
    if [[ -n "${ARG_ADD[0]}" ]]; then
        local file_name="${ARG_ADD[0]}"
        local full_path="$script_dir/$file_name"
        if [[ ! -f "$full_path" ]]; then
            output --info "Creating new script: $file_name"
            echo '#!/bin/bash' > "$full_path"
            chmod +x "$full_path"
        fi
        nvim "$full_path"
        
    elif [[ -n "${ARG_EDIT[0]}" ]]; then
        local file_name="${ARG_EDIT[0]}"
        local target_file="$script_dir/$file_name"
        [[ ! -f "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_name"
        [[ ! -f "$target_file" ]] && { output --error "Script not found: $file_name"; return 1; }
        nvim "$target_file"

    elif [[ -n "${ARG_DELETE[0]}" ]]; then
        local file_name="${ARG_DELETE[0]}"
        local target_file="$script_dir/$file_name"
        [[ ! -f "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_name"
        [[ ! -f "$target_file" ]] && { output --error "Script not found: $file_name"; return 1; }
        
        if question "Permanently delete '$(basename "$target_file")'?" --default-no; then
            rm -f "$target_file"
            output --ok "Deleted."
        fi
    else
        output --warn "No action specified (--add <file>, --edit <file>, --delete <file>)."
    fi
}

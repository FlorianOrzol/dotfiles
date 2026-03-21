#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container filesystem
# Manages local files mirroring the remote container structure.
# ==============================================================================

function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    local is_global=${ARG_GLOBAL:-0}
    
    if [[ -z "$ctid" ]] && (( ! is_global )); then
        output --error "Please specify a Container ID or use --global."
        return 1
    fi
    
    local fs_dir
    if (( is_global )); then
        fs_dir=$(ensure_fs_dir "global")
        output --info "Target: Global Filesystem"
    else
        fs_dir=$(ensure_fs_dir "container" "$ctid")
        output --info "Target: Container $ctid Filesystem"
    fi
    
    # --- ACTION: ADD ---
    if [[ -n "${ARG_ADD[0]}" ]]; then
        local file_path="${ARG_ADD[0]}"
        file_path="${file_path#/}" # Strip leading slash
        local full_path="$fs_dir/$file_path"
        
        if [[ -f "$full_path" ]]; then
            output --warn "File already exists. Opening in editor..."
        else
            output --info "Creating new file: $file_path"
            mkdir -p "$(dirname "$full_path")"
            touch "$full_path"
            [[ "$file_path" == *.sh ]] && echo '#!/bin/bash' > "$full_path" && chmod +x "$full_path"
        fi
        nvim "$full_path"
        
    # --- ACTION: EDIT ---
    elif [[ -n "${ARG_EDIT[0]}" ]]; then
        local file_path="${ARG_EDIT[0]}"
        local target_file="$fs_dir/$file_path"
        
        [[ ! -f "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_path" # Fallback
        [[ ! -f "$target_file" ]] && { output --error "File not found: $file_path"; return 1; }
        
        output --info "Editing: $target_file"
        nvim "$target_file"

    # --- ACTION: DELETE ---
    elif [[ -n "${ARG_DELETE[0]}" ]]; then
        local file_path="${ARG_DELETE[0]}"
        local target_file="$fs_dir/$file_path"
        
        [[ ! -f "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_path"
        [[ ! -f "$target_file" ]] && { output --error "File not found: $file_path"; return 1; }
        
        if question "Permanently delete '$(basename "$target_file")'?" --default-no; then
            rm -f "$target_file"
            rmdir -p "$(dirname "$target_file")" 2>/dev/null || true # Cleanup empty dirs
            output --ok "Deleted."
        fi
    else
        output --warn "No action specified (--add <file>, --edit <file>, --delete <file>)."
    fi
}

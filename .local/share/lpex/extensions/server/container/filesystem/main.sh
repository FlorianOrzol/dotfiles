#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container filesystem
# Description: Manages the local 'Tree Mirror' filesystem. Features enterprise
# safety features like automated Git vaulting before overwriting system files
# and synchronized remote deletion.
# ==============================================================================

function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    local active_host=$(get_active_host)
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
    
    # ==========================================================================
    # --- ACTION: ADD (The Smart Vault) ---
    # ==========================================================================
    if [[ -n "${ARG_ADD[0]}" ]]; then
        local file_path="${ARG_ADD[0]}"
        file_path="${file_path#/}" # Strip leading slash
        local full_path="$fs_dir/$file_path"
        local remote_dest="/$file_path"
        
        if [[ -f "$full_path" ]]; then
            output --warn "File already exists locally. Opening in editor..."
            nvim "$full_path"
            return 0
        fi

        output --info "Preparing: $file_path"
        mkdir -p "$(dirname "$full_path")"

        # --- Check if file exists on Remote Server ---
        if (( ! is_global )) && lx cmd --run "ssh root@$active_host 'pct exec $ctid -- [ -f \"$remote_dest\" ]'" --quiet --no-error-msg; then
            output --warn "File exists on Server! Executing Smart Vault Protocol..."
            
            local safe_name=$(basename "$remote_dest")
            local tmp_tar="/tmp/lpex_vault_${ctid}_${safe_name}.tar.gz"
            local local_tar="/tmp/lpex_vault_local.tar.gz"

            output --info "1. Fetching Original..."
            lx cmd --run "ssh root@$active_host 'pct exec $ctid -- bash -c \"cd \\\"$(dirname "$remote_dest")\\\" && tar -czf /tmp/vault.tar.gz \\\"$safe_name\\\"\"'" --quiet
            lx cmd --run "ssh root@$active_host 'pct pull $ctid /tmp/vault.tar.gz \"$tmp_tar\"'" --quiet
            lx cmd --run "rsync -avz root@$active_host:\"$tmp_tar\" \"$local_tar\"" --quiet
            
            tar -xzf "$local_tar" -C "$(dirname "$full_path")"
            lx cmd --run "ssh root@$active_host 'rm -f \"$tmp_tar\"; pct exec $ctid -- rm -f /tmp/vault.tar.gz'; rm -f \"$local_tar\"" --quiet

            output --info "2. Vaulting into Private Git Repo..."
            local private_git="$HOME/.git-dotfiles/private"
            
            # Use -f to bypass any .gitignore rules
            lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME add -f '$full_path'" --quiet
            lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME commit -m 'Auto-Vault Original: $file_path (CT $ctid)'" --quiet || true
            lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME push -u origin HEAD" --quiet --no-error-msg || output --error "Git push failed, but file is committed locally."

            output --ok "Original safely vaulted! Opening editor..."
        else
            output --info "Creating completely new file..."
            touch "$full_path"
            [[ "$file_path" == *.sh ]] && echo '#!/bin/bash' > "$full_path" && chmod +x "$full_path"
        fi
        
        nvim "$full_path"
        
    # ==========================================================================
    # --- ACTION: EDIT ---
    # ==========================================================================
    elif [[ -n "${ARG_EDIT[0]}" ]]; then
        local file_path="${ARG_EDIT[0]}"
        local target_file="$fs_dir/$file_path"
        
        [[ ! -f "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_path"
        [[ ! -f "$target_file" ]] && { output --error "File not found: $file_path"; return 1; }
        
        output --info "Editing: $target_file"
        nvim "$target_file"

    # ==========================================================================
    # --- ACTION: DELETE ---
    # ==========================================================================
    elif [[ -n "${ARG_DELETE[0]}" ]]; then
        local file_path="${ARG_DELETE[0]}"
        local target_file="$fs_dir/$file_path"
        
        [[ ! -f "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_path"
        [[ ! -f "$target_file" ]] && { output --error "File not found: $file_path"; return 1; }
        
        local msg="Permanently delete '$(basename "$target_file")' locally?"
        (( ARG_REMOTE )) && msg="Permanently delete '$(basename "$target_file")' LOCALLY AND ON SERVER?"

        if question "$msg" --default-no; then
            # 1. Local Delete
            rm -f "$target_file"
            rmdir -p "$(dirname "$target_file")" 2>/dev/null || true
            output --ok "Deleted locally."

            # 2. Remote Delete
            if (( ARG_REMOTE )) && (( ! is_global )); then
                local remote_dest="/${file_path#/}"
                output --info "Deleting from Server ($remote_dest)..."
                if lx cmd --run "ssh root@$active_host 'pct exec $ctid -- rm -rf \"$remote_dest\"'" --quiet; then
                    output --ok "Deleted on server."
                else
                    output --error "Failed to delete on server."
                fi
            fi
        fi
    else
        output --warn "No action specified (--add <file>, --edit <file>, --delete <file>)."
    fi
}

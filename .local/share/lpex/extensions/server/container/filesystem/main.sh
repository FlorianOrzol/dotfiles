#!/bin/bash
# ==============================================================================
# @meta_module      : server container filesystem
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Manages the local tree-mirror for container filesystem payloads.
# @desc_detailed    : Implements the Smart Vault: before creating a file locally that
# @desc_detailed    : already exists in the container, the original is fetched and
# @desc_detailed    : committed to the private Git repo as an immutable backup.
#
# @arg_values       : --ctid     | Target container ID (fzf-selectable)
# @arg_flags        : --global   | Operate on the shared global container pool
# @arg_values       : --add      | Create a new local file or fetch an existing one
# @arg_values       : --edit     | Open an existing local file in the editor
# @arg_values       : --delete   | Delete a local file or directory
# @arg_flags        : --remote   | Used with --delete: also delete on the container
# @arg_flags        : --no-vault | Skip the Smart Vault remote check for known-new files
#
# @exit_codes       : 0 | Action completed
# @exit_codes       : 1 | Missing ctid/scope or path not found
# ==============================================================================

function extension_start() {
    
    # --- 1. Resolve Context ---
    enforce_config_var "USER_PVE"

    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]}"
    local is_global=${ARG_GLOBAL:-0}
    
    if [[ -z "$ctid" ]] && (( ! is_global )); then
        output --error "Please specify a Container ID (--ctid) or use --global."
        return 1
    fi
    
    # Calculate the targeted local directory based on scope
    local fs_dir
    if (( is_global )); then
        fs_dir=$(ensure_fs_dir "global")
        output --info "Target: Global Filesystem"
    else
        fs_dir=$(ensure_fs_dir "container" "$ctid")
        output --info "Target: Container $ctid Filesystem"
    fi
    
    # ==========================================================================
    # --- ACTION: ADD (The Smart Vault Implementation) ---
    # Creating a file locally is dangerous if it already exists on the server
    # and has never been backed up. This function intercepts the creation,
    # pulls the original from the server, and vaults it into the private Git repo.
    # ==========================================================================
    if [[ -n "${ARG_ADD[0]}" ]]; then
        local file_path="${ARG_ADD[0]}"
        file_path="${file_path#/}" # Enforce relative path logic
        local full_path="$fs_dir/$file_path"
        local remote_dest="/$file_path"
        
        # Abort creation if we already have it locally
        if [[ -e "$full_path" ]]; then
            output --warn "Path already exists locally. Opening in editor..."
            nvim "$full_path"
            return 0
        fi

        output --info "Preparing: $file_path"
        mkdir -p "$(dirname "$full_path")"

        # [LOGIC] --no-vault skips the remote existence check and vault backup entirely.
        # Use this when the file is known to be new and the round-trip SSH call is unnecessary.
        if (( ARG_NO_VAULT )); then
            output --info "Vault skipped (--no-vault)."
            if [[ "$file_path" == */ ]]; then
                mkdir -p "$full_path"
            else
                touch "$full_path"
                [[ "$file_path" == *.sh ]] && echo '#!/bin/bash' > "$full_path" && chmod +x "$full_path"
            fi
            nvim "$full_path"
            return 0
        fi

        # --- Feature: Server Introspection ---
        # Ping the server to see if we are about to overwrite a system file
        if (( ! is_global )) && lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- [ -e \"$remote_dest\" ]'" --quiet --no-error-msg; then
            output --warn "Path exists on Server! Executing Smart Vault Protocol..."
            
            local safe_name=$(basename "$remote_dest")
            local tmp_tar="/tmp/lpex_vault_${ctid}_${safe_name}.tar.gz"
            local local_tar="/tmp/lpex_vault_local.tar.gz"

            # Phase 1: Secure Extraction
            output --info "1. Fetching Original..."
            local is_dir=0
            if lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- [ -d \"$remote_dest\" ]'" --quiet --no-error-msg; then
                is_dir=1
            fi

            if (( is_dir )); then
                lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- bash -c \"cd \\\"$remote_dest\\\" && tar -czf /tmp/vault.tar.gz .\"'" --quiet
            else
                lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- bash -c \"cd \\\"$(dirname "$remote_dest")\\\" && tar -czf /tmp/vault.tar.gz \\\"$safe_name\\\"\"'" --quiet
            fi

            lx cmd --run "ssh $USER_PVE@$active_host 'pct pull $ctid /tmp/vault.tar.gz \"$tmp_tar\"'" --quiet
            lx cmd --run "rsync -avz $USER_PVE@$active_host:\"$tmp_tar\" \"$local_tar\"" --quiet
            
            if (( is_dir )); then
                mkdir -p "$full_path"
                tar -xzf "$local_tar" -C "$full_path"
            else
                tar -xzf "$local_tar" -C "$(dirname "$full_path")"
            fi
            
            # Clean up the extraction pipeline
            lx cmd --run "ssh $USER_PVE@$active_host 'rm -f \"$tmp_tar\"; pct exec $ctid -- rm -f /tmp/vault.tar.gz'; rm -f \"$local_tar\"" --quiet

            # Phase 2: Git Vaulting
            output --info "2. Vaulting into Private Git Repo..."
            local private_git="$HOME/.git-dotfiles/private"
            
            # We use 'add -f' to punch through any global .gitignore restrictions
            lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME add -f '$full_path'" --quiet
            lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME commit -m 'Auto-Vault Original: $file_path (CT $ctid)'" --quiet || true
            lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME push -u origin HEAD" --quiet --no-error-msg || output --error "Git push failed, but file is safely committed locally."

            output --ok "Original safely vaulted! Opening editor..."
        else
            # Path is truly new; generate a blank canvas
            output --info "Creating completely new path..."
            if [[ "$file_path" == */ ]]; then
                mkdir -p "$full_path" # It's a directory request
            else
                touch "$full_path"
                # Convenience: Make scripts immediately executable
                [[ "$file_path" == *.sh ]] && echo '#!/bin/bash' > "$full_path" && chmod +x "$full_path"
            fi
        fi
        
        nvim "$full_path"
        
    # ==========================================================================
    # --- ACTION: EDIT ---
    # ==========================================================================
    elif [[ -n "${ARG_EDIT[0]}" ]]; then
        local file_path="${ARG_EDIT[0]}"
        local target_file="$fs_dir/$file_path"
        
        # We use -e to gracefully allow the editing of directories (Netrw in Neovim)
        [[ ! -e "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_path"
        [[ ! -e "$target_file" ]] && { output --error "Path not found: $file_path"; return 1; }
        
        output --info "Editing: $target_file"
        nvim "$target_file"

    # ==========================================================================
    # --- ACTION: DELETE (With Remote Sync Option) ---
    # ==========================================================================
    elif [[ -n "${ARG_DELETE[0]}" ]]; then
        local file_path="${ARG_DELETE[0]}"
        local target_file="$fs_dir/$file_path"
        
        [[ ! -e "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_path"
        [[ ! -e "$target_file" ]] && { output --error "Path not found: $file_path"; return 1; }
        
        local msg="Permanently delete '$(basename "$target_file")' locally?"
        (( ARG_REMOTE )) && msg="Permanently delete '$(basename "$target_file")' LOCALLY AND ON SERVER?"

        if question "$msg" --default-no; then
            # Phase 1: Wipe local presence (recursive for folders)
            rm -rf "$target_file"
            rmdir -p "$(dirname "$target_file")" 2>/dev/null || true
            output --ok "Deleted locally."

            # Phase 2: Synchronize wipe to Proxmox
            if (( ARG_REMOTE )) && (( ! is_global )); then
                # Strip trailing slash to ensure clean rm command
                local remote_dest="/${file_path#/}"
                remote_dest="${remote_dest%/}"
                
                output --info "Deleting from Server ($remote_dest)..."
                if lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- rm -rf \"$remote_dest\"'" --quiet; then
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

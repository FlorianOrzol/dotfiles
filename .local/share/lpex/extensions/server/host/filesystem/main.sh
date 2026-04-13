#!/bin/bash
# ==============================================================================
# @meta_module      : server host filesystem
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Manages the local tree-mirror for Proxmox host filesystem payloads.
# @desc_detailed    : Implements the Smart Vault: before creating a file locally that
# @desc_detailed    : already exists on the host, the original is fetched and committed
# @desc_detailed    : to the private Git repo as an immutable backup.
#
# @arg_values       : --node      | Target Proxmox node (pve101, pve102, pve103)
# @arg_flags        : --global    | Operate on the shared global host pool
# @arg_values       : --add       | Create a new local file or fetch an existing one
# @arg_values       : --edit      | Open an existing local file in the editor
# @arg_values       : --delete    | Delete a local file or directory
# @arg_flags        : --remote    | Used with --delete: also delete on the host
# @arg_flags        : --no-vault  | Skip the Smart Vault remote check for known-new files
#
# @exit_codes       : 0 | Action completed
# @exit_codes       : 1 | Missing node/scope or path not found
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_PVE"
    
    local node="${ARG_NODE[0]}"
    local is_global=${ARG_GLOBAL:-0}
    
    if [[ -z "$node" ]] && (( ! is_global )); then
        output --error "Please specify a Node (--node) or use --global."
        return 1
    fi
    
    local fs_dir
    local ip=""
    if (( is_global )); then
        fs_dir=$(ensure_fs_dir "global" "host")
        output --info "Target: Global Host Filesystem"
    else
        local node_upper="${node^^}"
        local ip_var="IP_${node_upper}"
        ip="${!ip_var}"
        [[ -z "$ip" ]] && { output --error "IP not found for $node."; return 1; }
        
        fs_dir=$(ensure_fs_dir "host" "$node")
        output --info "Target: Host $node Filesystem"
    fi
    
    # ==========================================================================
    # --- ACTION: ADD (The Smart Vault) ---
    # ==========================================================================
    if [[ -n "${ARG_ADD[0]}" ]]; then
        local file_path="${ARG_ADD[0]#/}"
        local full_path="$fs_dir/$file_path"
        local remote_dest="/$file_path"
        
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

        if (( ! is_global )) && lx cmd --run "ssh $USER_PVE@$ip '[ -e \"$remote_dest\" ]'" --quiet --no-error-msg; then
            output --warn "Path exists on Host! Executing Smart Vault Protocol..."
            
            local safe_name=$(basename "$remote_dest")
            local tmp_tar="/tmp/lpex_vault_${node}_${safe_name}.tar.gz"
            local local_tar="/tmp/lpex_vault_local.tar.gz"

            output --info "1. Fetching Original..."
            local is_dir=0
            lx cmd --run "ssh $USER_PVE@$ip '[ -d \"$remote_dest\" ]'" --quiet --no-error-msg && is_dir=1

            if (( is_dir )); then
                lx cmd --run "ssh $USER_PVE@$ip 'cd \"$remote_dest\" && tar -czf $tmp_tar .'" --quiet
            else
                lx cmd --run "ssh $USER_PVE@$ip 'cd \"$(dirname "$remote_dest")\" && tar -czf $tmp_tar \"$safe_name\"'" --quiet
            fi

            lx cmd --run "rsync -avz $USER_PVE@$ip:\"$tmp_tar\" \"$local_tar\"" --quiet
            
            if (( is_dir )); then
                mkdir -p "$full_path"
                tar -xzf "$local_tar" -C "$full_path"
            else
                tar -xzf "$local_tar" -C "$(dirname "$full_path")"
            fi
            
            lx cmd --run "ssh $USER_PVE@$ip 'rm -f \"$tmp_tar\"'; rm -f \"$local_tar\"" --quiet

            output --info "2. Vaulting into Private Git Repo..."
            local private_git="$HOME/.git-dotfiles/private"
            lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME add -f '$full_path'" --quiet
            lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME commit -m 'Auto-Vault Original: $file_path (Host $node)'" --quiet || true
            lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME push -u origin HEAD" --quiet --no-error-msg || true

            output --ok "Original safely vaulted! Opening editor..."
        else
            output --info "Creating completely new path..."
            if [[ "$file_path" == */ ]]; then
                mkdir -p "$full_path"
            else
                touch "$full_path"
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
        [[ ! -e "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_path"
        [[ ! -e "$target_file" ]] && { output --error "Path not found: $file_path"; return 1; }
        
        output --info "Editing: $target_file"
        nvim "$target_file"

    # ==========================================================================
    # --- ACTION: DELETE ---
    # ==========================================================================
    elif [[ -n "${ARG_DELETE[0]}" ]]; then
        local file_path="${ARG_DELETE[0]}"
        local target_file="$fs_dir/$file_path"
        [[ ! -e "$target_file" ]] && target_file="$PATH_EXTENSION_DATA/$file_path"
        [[ ! -e "$target_file" ]] && { output --error "Path not found: $file_path"; return 1; }
        
        local msg="Permanently delete '$(basename "$target_file")' locally?"
        (( ARG_REMOTE )) && msg="Permanently delete '$(basename "$target_file")' LOCALLY AND ON SERVER?"

        if question "$msg" --default-no; then
            rm -rf "$target_file"
            rmdir -p "$(dirname "$target_file")" 2>/dev/null || true
            output --ok "Deleted locally."

            if (( ARG_REMOTE )) && (( ! is_global )); then
                local remote_dest="/${file_path#/}"
                remote_dest="${remote_dest%/}"
                output --info "Deleting from Server ($remote_dest)..."
                if lx cmd --run "ssh $USER_PVE@$ip 'rm -rf \"$remote_dest\"'" --quiet; then
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

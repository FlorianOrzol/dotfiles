#!/bin/bash
# ==============================================================================
# @meta_module      : server host push
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Deploys local tree-mirror files to one or more Proxmox hosts.
# @desc_detailed    : Supports multi-node rollout via --node repeated. Resolves
# @desc_detailed    : node-specific paths first, then falls back to the global pool.
# @desc_detailed    : Directories are transferred via tar-pipe (contents only, never
# @desc_detailed    : deletes remote files that have no local counterpart).
# @desc_detailed    : Use --local-file . to push the entire tree-mirror to the host.
# @desc_detailed    : Shell scripts receive chmod +x automatically after transfer.
#
# @arg_values       : --node       | Target Proxmox node(s), repeatable for multi-push
# @arg_values       : --local-file | Relative path from local tree; "." pushes everything
#
# @exit_codes       : 0 | All files deployed successfully
# @exit_codes       : 1 | Missing node/local-file, IP resolution failure, or rsync error
# ==============================================================================

function extension_start() {
    # Ensure the SSH user for PVE hosts is configured before proceeding
    enforce_config_var "USER_PVE"

    # Collect all specified target nodes and local file paths from argument arrays
    local target_nodes=("${ARG_NODE[@]}")
    local local_paths=("${ARG_LOCAL_FILE[@]}")

    # Abort early if either required argument group is missing
    if [[ ${#target_nodes[@]} -eq 0 || ${#local_paths[@]} -eq 0 ]]; then
        output --error "Usage: lpex server host push --node <node> --local-file <path|.>"
        return 1
    fi

    # Resolve the global host pool once — used as fallback when no node-specific file exists
    local global_dir
    global_dir=$(ensure_fs_dir "global" "host")

    # Outer loop: iterate over each specified target node
    for node in "${target_nodes[@]}"; do
        output --section "Pushing to Host: $node"

        # Convert node name to uppercase to build the config variable name (e.g. IP_PVE101)
        local node_upper="${node^^}"
        local ip_var="IP_${node_upper}"
        local ip="${!ip_var}"

        # Abort this node if its IP is not defined in config.conf
        [[ -z "$ip" ]] && { output --error "IP not found for $node (${ip_var} not set in config.conf)."; continue; }

        # Resolve the node-specific tree-mirror directory for this host
        local specific_dir
        specific_dir=$(ensure_fs_dir "host" "$node")

        # Inner loop: iterate over each specified file or directory path
        for file_path in "${local_paths[@]}"; do
            # Strip any accidental trailing slash from the input
            file_path="${file_path%/}"

            # ==================================================================
            # --- Feature: Full Tree-Mirror Push ("." shorthand) ---
            # Passing "." means "push everything from this node's tree-mirror".
            # We normalize it to an empty string so that remote_dest becomes "/"
            # and abs_file resolves to the tree-mirror root directory.
            # IMPORTANT: tar-pipe extraction never deletes remote files that have
            # no local counterpart — this is an additive-only operation.
            # ==================================================================
            [[ "$file_path" == "." ]] && file_path=""

            # [LOGIC] Tree-mirror principle: the remote absolute path is always
            # the local relative path with a leading "/" prepended. The local
            # directory structure under .../filesystem/ mirrors the remote root.
            local remote_dest="/${file_path#/}"

            # ==================================================================
            # --- Source Resolution: --source-path bypass OR tree-mirror lookup ---
            #
            # Mode A — Direct push (--source-path provided):
            #   The caller specifies an absolute local path (e.g. ~/.private/priv_data).
            #   --local-file in this case ONLY determines the remote destination path.
            #   The tree-mirror is bypassed entirely. Useful for private/sensitive
            #   files that must not be copied into the LPEX state directory.
            #
            # Mode B — Tree-mirror lookup (default, no --source-path):
            #   Files in the node-specific pool (e.g. host/pve101/filesystem/)
            #   override files of the same relative path in the global pool.
            # ==================================================================
            local abs_file=""
            if [[ -n "${ARG_SOURCE_PATH[0]}" ]]; then
                # Mode A: direct path provided — expand ~ and validate existence
                abs_file="$(realpath "${ARG_SOURCE_PATH[0]/#\~/$HOME}")"
                if [[ ! -e "$abs_file" ]]; then
                    output --error "Source path not found: ${ARG_SOURCE_PATH[0]}"
                    continue
                fi
                output --info "Direct source: $abs_file (tree-mirror bypassed)"
            elif [[ -e "$specific_dir/$file_path" ]]; then
                # Mode B, node-specific: found in the per-node tree-mirror
                abs_file="$(realpath "$specific_dir/$file_path")"
                output --info "Matched node-specific path."
            elif [[ -e "$global_dir/$file_path" ]]; then
                # Mode B, global fallback: use the shared host pool
                abs_file="$(realpath "$global_dir/$file_path")"
                output --info "Matched global fallback pool."
            else
                # Not found in any location — skip this file with a helpful hint
                output --error "Path not found: $file_path"
                output --warn  "Expected at: $specific_dir/$file_path"
                output --warn  "         or: $global_dir/$file_path"
                output --warn  "Use --source-path <abs_path> to push a file outside the tree-mirror."
                continue
            fi

            output --info "Preparing: $file_path → $remote_dest"

            # ==================================================================
            # --- Feature: Directory Push (Tar-Pipe) ---
            # For directories we pack the CONTENTS (not the folder itself) into
            # a tarball and extract it into the remote destination directory.
            #
            # Why tar-pipe instead of rsync with --recursive?
            #   rsync --delete would remove remote files not present locally.
            #   We explicitly do NOT want that behaviour: files that exist on the
            #   host but have no local counterpart must never be touched.
            #   tar -xzf only adds and overwrites — it never deletes anything.
            #
            # Why -C "$abs_file" . (pack contents, not the folder)?
            #   Without -C, tar would create a nested subfolder inside remote_dest.
            #   With -C, "." refers to the contents directly, so extraction into
            #   an existing $remote_dest correctly updates files in place.
            # ==================================================================
            if [[ -d "$abs_file" ]]; then
                output --info "Target is a DIRECTORY. Packing contents into tarball..."

                # Use a unique local tmp filename to avoid collisions during parallel pushes
                local local_tar="/tmp/lpex_host_push_${node}_$(basename "${abs_file:-root}").tar.gz"

                # Pack the contents of the local directory into the tarball
                if ! tar -czf "$local_tar" -C "$abs_file" .; then
                    output --error "Failed to create local tarball."
                    continue
                fi

                # Use a matching unique filename on the remote /tmp
                local remote_tar="/tmp/lpex_host_push_${node}_$(basename "${abs_file:-root}").tar.gz"

                output --info "-> Transferring tarball to $node:/tmp..."
                # rsync the tarball to the host's /tmp — we connect as USER_PVE (root on Proxmox)
                if ! lx cmd --run "rsync -avz '$local_tar' $USER_PVE@$ip:'$remote_tar'" \
                        --quiet --error-msg "rsync of tarball failed"; then
                    # Clean up the local tarball even on failure to avoid leftover files
                    rm -f "$local_tar"
                    continue
                fi

                # Local tarball is no longer needed after a successful transfer
                rm -f "$local_tar"

                # [LOGIC] Prompt for confirmation before a full root push ("/")
                # to prevent accidental mass-overwrite of system files.
                if [[ "$remote_dest" == "/" ]]; then
                    output --warn "About to extract the ENTIRE tree-mirror to / on $node."
                    output --warn "Existing files will be overwritten. Remote-only files are NOT deleted."
                    if ! question "Continue with full tree-mirror push to $node?" --default-no; then
                        lx cmd --run "ssh $USER_PVE@$ip 'rm -f \"$remote_tar\"'" --quiet
                        output --info "Aborted."
                        continue
                    fi
                fi

                output --info "-> Extracting at $remote_dest on $node..."
                # On Proxmox hosts USER_PVE is root, so no sudo is needed.
                # mkdir -p ensures the destination exists even if it is new.
                # tar -xzf extracts contents in place — no files are ever deleted.
                lx cmd --run "ssh $USER_PVE@$ip 'mkdir -p \"$remote_dest\" && tar -xzf \"$remote_tar\" -C \"$remote_dest\" && rm -f \"$remote_tar\"'" \
                       --quiet --error-msg "Extraction failed on $node"

                output --ok "Directory deployed: $remote_dest"

            # ==================================================================
            # --- Feature: Single File Push ---
            # For individual files we rsync directly to the final destination.
            # USER_PVE is root on Proxmox, so no sudo or tmp-staging is needed.
            # ==================================================================
            else
                output --info "Target is a FILE. Transferring directly..."

                # Derive the parent directory of the remote destination for mkdir -p
                local remote_parent
                remote_parent=$(dirname "$remote_dest")

                # Ensure the parent directory exists on the remote host
                lx cmd --run "ssh $USER_PVE@$ip 'mkdir -p \"$remote_parent\"'" --quiet

                # rsync the file directly to its final remote path
                # No --delete flag: only this specific file is affected, nothing else.
                if lx cmd --run "rsync -avz '$abs_file' $USER_PVE@$ip:\"$remote_dest\"" \
                        --quiet --error-msg "rsync failed for $file_path"; then

                    # [LOGIC] Set execute permission for shell scripts after transfer.
                    # The source file may lack +x if it was freshly created via touch.
                    # We set it explicitly to guarantee the script is runnable on the host.
                    [[ "$abs_file" == *.sh ]] && lx cmd --run \
                        "ssh $USER_PVE@$ip 'chmod +x \"$remote_dest\"'" --quiet

                    output --ok "File deployed: $remote_dest"
                fi
            fi
        done
    done
}

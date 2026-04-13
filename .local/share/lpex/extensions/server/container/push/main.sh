#!/bin/bash
# ==============================================================================
# @meta_module      : server container push
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Deploys local tree-mirror files into one or more LXC containers.
# @desc_detailed    : Supports multi-container rollout via --ctid repeated. Resolves
# @desc_detailed    : container-specific paths first, then falls back to the global pool.
# @desc_detailed    : Directories are transferred via tar-pipe (pct push + pct exec).
# @desc_detailed    : Contents only — no remote files are ever deleted.
# @desc_detailed    : Use --local-file . to push the entire tree-mirror to the container.
# @desc_detailed    : Shell scripts receive chmod +x automatically after transfer.
#
# @arg_values       : --ctid       | Target container ID(s), repeatable for multi-push
# @arg_values       : --local-file | Relative path from local tree; "." pushes everything
#
# @exit_codes       : 0 | All files deployed successfully
# @exit_codes       : 1 | Missing ctid/local-file or transfer failure
# ==============================================================================

function extension_start() {
    # Ensure the SSH user for PVE hosts is configured (we SSH to the host, then use pct)
    enforce_config_var "USER_PVE"

    # Resolve the currently active Proxmox host (where the containers reside)
    local active_host
    active_host=$(get_active_host)

    # Collect all specified target container IDs and local file paths
    local target_ctids=("${ARG_CTID[@]}")
    local local_paths=("${ARG_LOCAL_FILE[@]}")

    # Abort early if either required argument group is missing
    if [[ ${#target_ctids[@]} -eq 0 || ${#local_paths[@]} -eq 0 ]]; then
        output --error "Usage: lpex server container push --ctid <ID> --local-file <path|.>"
        return 1
    fi

    # Resolve the global container pool once — used as fallback when no container-specific file exists
    local global_dir
    global_dir=$(ensure_fs_dir "global" "container")

    # Outer loop: iterate over each specified target container
    for ctid in "${target_ctids[@]}"; do
        output --section "Pushing to Container: CT $ctid"

        # Resolve the container-specific tree-mirror directory
        local specific_dir
        specific_dir=$(ensure_fs_dir "container" "$ctid")

        # Inner loop: iterate over each specified file or directory path
        for file_path in "${local_paths[@]}"; do
            # Strip any accidental trailing slash from the input
            file_path="${file_path%/}"

            # ==================================================================
            # --- Feature: Full Tree-Mirror Push ("." shorthand) ---
            # Passing "." means "push everything from this container's tree-mirror".
            # We normalize it to an empty string so that remote_dest becomes "/"
            # and abs_file resolves to the tree-mirror root directory.
            # IMPORTANT: tar extraction never deletes remote files that have no
            # local counterpart — this is an additive-only operation.
            # ==================================================================
            [[ "$file_path" == "." ]] && file_path=""

            # [LOGIC] Tree-mirror principle: the remote absolute path inside the
            # container is always the local relative path with a leading "/" prepended.
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
            #   Container-specific files (e.g. container/1111/filesystem/) override
            #   files of the same relative path in the global container pool.
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
                # Mode B, container-specific: found in the per-container tree-mirror
                abs_file="$(realpath "$specific_dir/$file_path")"
                output --info "Matched container-specific path."
            elif [[ -e "$global_dir/$file_path" ]]; then
                # Mode B, global fallback: use the shared container pool
                abs_file="$(realpath "$global_dir/$file_path")"
                output --info "Matched global fallback pool."
            else
                # Not found in any location — skip with a helpful hint
                output --error "Path not found: $file_path"
                output --warn  "Expected at: $specific_dir/$file_path"
                output --warn  "         or: $global_dir/$file_path"
                output --warn  "Use --source-path <abs_path> to push a file outside the tree-mirror."
                continue
            fi

            output --info "Preparing: $file_path → $remote_dest"

            # Derive a safe basename for tmp staging files on the host
            local safe_name
            safe_name=$(basename "${abs_file:-root}")

            # ==================================================================
            # --- Feature: Directory Push (Tar-Pipe via pct) ---
            # pct push does not support directories — only single files.
            # For directories we pack the CONTENTS into a tarball locally,
            # rsync it to the host's /tmp, push the tarball into the container
            # via pct push, and then extract it with pct exec.
            #
            # Why not rsync with --recursive and --delete?
            #   We must not delete remote files that have no local counterpart.
            #   tar -xzf only adds and overwrites — it never deletes.
            #
            # Why -C "$abs_file" . (pack contents, not the folder)?
            #   Without -C, tar would create a nested subfolder at remote_dest.
            #   With -C, "." captures the contents directly, so extraction into
            #   an existing $remote_dest correctly updates files in place.
            # ==================================================================
            if [[ -d "$abs_file" ]]; then
                output --info "Target is a DIRECTORY. Packing contents into tarball..."

                # Use unique tmp filenames to avoid collisions during parallel pushes
                local local_tar="/tmp/lpex_ct_push_${ctid}_${safe_name}.tar.gz"
                local host_tar="/tmp/lpex_ct_push_${ctid}_${safe_name}.tar.gz"
                local ct_tar="/tmp/lpex_ct_push_${ctid}_${safe_name}.tar.gz"

                # Pack the contents of the local directory into the tarball
                if ! tar -czf "$local_tar" -C "$abs_file" .; then
                    output --error "Failed to create local tarball."
                    continue
                fi

                output --info "-> Staging tarball on Host /tmp..."
                # Transfer the tarball to the Proxmox host's /tmp via rsync
                if ! lx cmd --run "rsync -avz '$local_tar' $USER_PVE@$active_host:'$host_tar'" \
                        --quiet --error-msg "rsync of tarball to host failed"; then
                    rm -f "$local_tar"
                    continue
                fi

                # Local tarball is no longer needed after a successful transfer
                rm -f "$local_tar"

                output --info "-> Pushing tarball into Container CT $ctid..."
                # pct push transfers a single file from the host into the container
                if ! lx cmd --run "ssh $USER_PVE@$active_host 'pct push $ctid \"$host_tar\" \"$ct_tar\"'" \
                        --quiet --error-msg "pct push of tarball failed"; then
                    # Clean up the host-side tarball even on failure
                    lx cmd --run "ssh $USER_PVE@$active_host 'rm -f \"$host_tar\"'" --quiet
                    continue
                fi

                # [LOGIC] Prompt for confirmation before a full root push ("/")
                # to prevent accidental mass-overwrite inside the container.
                if [[ "$remote_dest" == "/" ]]; then
                    output --warn "About to extract the ENTIRE tree-mirror to / in CT $ctid."
                    output --warn "Existing files will be overwritten. Container-only files are NOT deleted."
                    if ! question "Continue with full tree-mirror push to CT $ctid?" --default-no; then
                        lx cmd --run "ssh $USER_PVE@$active_host 'rm -f \"$host_tar\"; pct exec $ctid -- rm -f \"$ct_tar\"'" --quiet
                        output --info "Aborted."
                        continue
                    fi
                fi

                output --info "-> Extracting at $remote_dest inside CT $ctid..."
                # pct exec runs as root inside the container — no sudo needed.
                # mkdir -p ensures the destination exists even if it is new.
                # tar -xzf extracts contents in place — no files are ever deleted.
                lx cmd --run "ssh $USER_PVE@$active_host \
                    'pct exec $ctid -- bash -c \"mkdir -p \\\"$remote_dest\\\" && tar -xzf \\\"$ct_tar\\\" -C \\\"$remote_dest\\\" && rm -f \\\"$ct_tar\\\"\"'" \
                    --quiet --error-msg "Extraction failed in CT $ctid"

                # Clean up the host-side tarball (container already cleaned its own copy above)
                lx cmd --run "ssh $USER_PVE@$active_host 'rm -f \"$host_tar\"'" --quiet

                output --ok "Directory deployed: $remote_dest"

            # ==================================================================
            # --- Feature: Single File Push ---
            # For individual files we stage on the host /tmp, then push into
            # the container via pct push. pct runs as root inside the container
            # so no sudo is needed regardless of the destination path.
            # ==================================================================
            else
                output --info "Target is a FILE. Staging on host /tmp..."

                local host_file="/tmp/lpex_ct_push_${ctid}_${safe_name}"

                # Step 1: rsync the file to the Proxmox host's /tmp
                if ! lx cmd --run "rsync -avz '$abs_file' $USER_PVE@$active_host:'$host_file'" \
                        --quiet --error-msg "rsync to host failed"; then
                    continue
                fi

                # Step 2: Ensure the parent directory exists inside the container
                local remote_parent
                remote_parent=$(dirname "$remote_dest")
                lx cmd --run "ssh $USER_PVE@$active_host 'pct exec $ctid -- mkdir -p \"$remote_parent\"'" --quiet

                output --info "-> Pushing into Container ($remote_dest)..."
                # Step 3: Transfer the file from host /tmp into the container via pct push
                if lx cmd --run "ssh $USER_PVE@$active_host 'pct push $ctid \"$host_file\" \"$remote_dest\"'" \
                        --quiet --error-msg "pct push failed for $remote_dest"; then

                    # [LOGIC] Set execute permission inside the container for shell scripts.
                    # The source file may lack +x if it was freshly created via touch.
                    [[ "$abs_file" == *.sh ]] && lx cmd --run \
                        "ssh $USER_PVE@$active_host 'pct exec $ctid -- chmod +x \"$remote_dest\"'" --quiet

                    output --ok "File deployed: $remote_dest"
                fi

                # Step 4: Clean up the staging file on the host regardless of success
                lx cmd --run "ssh $USER_PVE@$active_host 'rm -f \"$host_file\"'" --quiet
            fi
        done
    done
}

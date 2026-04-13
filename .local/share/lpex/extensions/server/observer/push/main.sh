#!/bin/bash
# ==============================================================================
# @meta_module      : server observer push
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Deploys scripts and systemd units to one or both Observer Pis.
# @desc_detailed    : Supports deploying to multiple nodes in one call (--node pi1 --node pi2).
# @desc_detailed    : File paths are resolved from the node-specific payload dir first,
# @desc_detailed    : then fall back to the global pool. Remote destination is derived
# @desc_detailed    : via tree-mirror (relative path → prepend "/").
# @desc_detailed    : Two convenience shorthand prefixes are expanded automatically:
# @desc_detailed    :   scripts/  → home/fadmin/scripts/
# @desc_detailed    :   systemd/  → etc/systemd/system/
# @desc_detailed    : Systemd units (*.service, *.timer) trigger daemon-reload after deploy.
# @desc_detailed    : Shell scripts (*.sh) receive chmod +x automatically.
# @desc_detailed    : System paths (/etc, /usr, /lib) are written via sudo mv/tar.
#
# @arg_values       : --node       | Target Observer node(s) — multi: pi1, pi2
# @arg_values       : --local-file | Relative path to deploy (multi-value, shorthand supported)
#
# @exit_codes       : 0 | All files deployed successfully
# @exit_codes       : 1 | Missing argument, file not found, or transfer failed
# ==============================================================================

function extension_start() {
    # Ensure the SSH user for the Observer is configured before doing anything
    enforce_config_var "USER_OBSERVER"

    # Collect all specified target nodes and file paths from the argument arrays
    local target_nodes=("${ARG_NODE[@]}")
    local local_paths=("${ARG_LOCAL_FILE[@]}")

    # Abort early if either required argument group is empty
    if [[ ${#target_nodes[@]} -eq 0 || ${#local_paths[@]} -eq 0 ]]; then
        output --error "Usage: lpex server observer push --node <pi1|pi2> --local-file <path>"
        return 1
    fi

    # Outer loop: iterate over each specified target node (supports pi1 and/or pi2)
    for node in "${target_nodes[@]}"; do

        # Resolve the SSH IP for this node via the central helper (reads from config.conf)
        local ip
        ip=$(get_observer_ip "$node")

        # Resolve both local search directories:
        # - specific_dir: node-specific payloads (e.g. observer/pi1/filesystem/)
        # - global_dir:   shared payloads for all observer nodes (global/observer/filesystem/)
        local specific_dir
        specific_dir=$(ensure_fs_dir "observer" "$node")
        local global_dir
        global_dir=$(ensure_fs_dir "global" "observer")

        output --section "Deploying to Observer: $node"

        # Inner loop: iterate over each specified file/directory path
        for file_path in "${local_paths[@]}"; do

            # Strip any accidental trailing slash from the input path
            file_path="${file_path%/}"

            # ==================================================================
            # --- Feature: Full Tree-Mirror Push ("." shorthand) ---
            # Passing "." means "push everything from this node's tree-mirror".
            # Normalize to empty string so remote_dest becomes "/" and abs_file
            # resolves to the tree-mirror root directory.
            # IMPORTANT: tar extraction never deletes remote files that have no
            # local counterpart — this is an additive-only operation.
            # ==================================================================
            [[ "$file_path" == "." ]] && file_path=""

            # ==================================================================
            # --- Feature: Path Shorthand Expansion ---
            # The tree-mirror stores files at their full relative path from root,
            # e.g. home/fadmin/scripts/observer/foo.sh or etc/systemd/system/foo.service.
            # Typing the full path every time is tedious for the two most common
            # directories, so we expand two convenience prefixes automatically.
            #
            # IMPORTANT: the expansion is purely a local lookup aid. The remote
            # destination is always derived from the expanded path → "/" + path.
            # There is no risk of landing in the wrong directory: a file found at
            # local .../filesystem/etc/... will always be deployed to /etc/... on
            # the Pi, never to ~/etc/... or any other location.
            # ==================================================================
            local original_path="$file_path"
            case "$file_path" in
                # "scripts/foo" → "home/fadmin/scripts/foo"
                # This is the home directory of the fadmin user on the Pi.
                scripts/*)
                    file_path="home/fadmin/scripts/${file_path#scripts/}"
                    ;;
                # "systemd/foo.service" → "etc/systemd/system/foo.service"
                # Systemd unit files always live in /etc/systemd/system/ on the Pi.
                systemd/*)
                    file_path="etc/systemd/system/${file_path#systemd/}"
                    ;;
            esac

            # Inform the user if the shorthand was actually expanded
            [[ "$file_path" != "$original_path" ]] && output --info "Expanded: $original_path → $file_path"

            # [LOGIC] Tree-mirror: remote destination is always "/" + relative path.
            # When file_path is empty (from "." normalization above), this yields "/".
            local remote_dest="/${file_path#/}"

            output --info "Preparing: ${file_path:-(full tree-mirror)} → $remote_dest"

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
            #   The relative path is resolved first in the node-specific pool,
            #   then in the global observer pool. This is the normal deploy flow.
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
                output --info "Matched node-specific payload."
            elif [[ -e "$global_dir/$file_path" ]]; then
                # Mode B, global fallback: use the shared observer pool
                abs_file="$(realpath "$global_dir/$file_path")"
                output --info "Matched global fallback pool."
            else
                # Not found in any location — skip this file with a helpful hint
                output --error "File not found: $file_path"
                output --warn  "Expected at: $specific_dir/$file_path"
                output --warn  "         or: $global_dir/$file_path"
                output --warn  "Use --source-path <abs_path> to push a file outside the tree-mirror."
                continue
            fi

            # Derive the parent directory of the remote destination for mkdir -p
            local remote_parent
            remote_parent=$(dirname "$remote_dest")

            # ==================================================================
            # --- Classify the target to determine deploy strategy ---
            # We need to know:
            #   is_systemd → triggers daemon-reload after deploy
            #   is_script  → triggers chmod +x after deploy
            #   needs_sudo → file lives in a system-owned path (requires sudo on Pi)
            # ==================================================================
            local is_systemd=0
            local is_script=0
            local needs_sudo=0

            # Systemd units are identified by their file extension
            [[ "$file_path" == *.service || "$file_path" == *.timer ]] && is_systemd=1

            # Shell scripts are identified by their file extension
            [[ "$file_path" == *.sh ]] && is_script=1

            # [LOGIC] Any path under /etc, /usr, or /lib requires root ownership.
            # We cannot write there as fadmin directly — sudo is required.
            # Systemd units (which live under /etc) are also covered by this check.
            [[ "$remote_dest" == /etc/* || "$remote_dest" == /usr/* || "$remote_dest" == /lib/* ]] && needs_sudo=1
            # Explicitly also set needs_sudo for systemd units in case they are placed elsewhere
            (( is_systemd )) && needs_sudo=1

            # ==================================================================
            # --- Feature: Directory Push (Tar-Pipe) ---
            # For directories we cannot use a simple rsync + mv approach because
            # if the remote directory already exists, "mv /tmp/src /dest" would
            # create /dest/src/ instead of merging into /dest/ — wrong behavior.
            #
            # Instead we pack the CONTENTS of the local directory (not the folder
            # itself) into a tarball and extract it into the remote destination.
            # This is safe for both new and existing remote directories: tar
            # overwrites individual files in place without touching other files.
            # ==================================================================
            if [[ -d "$abs_file" ]]; then
                output --info "Target is a DIRECTORY. Packing tarball of contents..."

                # Use a unique tmp filename to avoid collisions with parallel runs
                local local_tar="/tmp/lpex_obs_push_${node}_$(basename "$abs_file").tar.gz"

                # [LOGIC] -C changes into the source directory first so that tar
                # packs the *contents* (relative paths starting with "./") rather
                # than the directory itself. Extracting "." into $remote_dest then
                # correctly populates the destination without a nested subfolder.
                tar -czf "$local_tar" -C "$abs_file" .

                output --info "-> Transferring tarball to $node:/tmp..."
                local remote_tar="/tmp/lpex_obs_push_${node}_$(basename "$abs_file").tar.gz"
                if ! lx cmd --run "rsync -avz '$local_tar' $USER_OBSERVER@$ip:'$remote_tar'" \
                        --quiet --error-msg "rsync of tarball failed"; then
                    # Clean up the local tarball even on failure
                    rm -f "$local_tar"
                    continue
                fi

                # Local tarball is no longer needed after a successful transfer
                rm -f "$local_tar"

                # [LOGIC] Prompt for confirmation before a full root push ("/") to
                # prevent accidental mass-overwrite of the Pi's system files.
                if [[ "$remote_dest" == "/" ]]; then
                    output --warn "About to extract the ENTIRE tree-mirror to / on $node."
                    output --warn "Existing files will be overwritten. Remote-only files are NOT deleted."
                    if ! question "Continue with full tree-mirror push to $node?" --default-no; then
                        lx cmd --run "ssh $USER_OBSERVER@$ip 'sudo rm -f \"$remote_tar\"'" --quiet
                        output --info "Aborted."
                        continue
                    fi
                fi

                output --info "-> Extracting at $remote_dest..."

                # Build the remote extraction command — with or without sudo
                # depending on whether the target path requires root ownership
                local extract_cmd
                if (( needs_sudo )); then
                    # sudo mkdir ensures the destination exists, sudo tar extracts,
                    # sudo rm cleans up the remote tarball afterwards
                    extract_cmd="sudo mkdir -p '$remote_dest' && sudo tar -xzf '$remote_tar' -C '$remote_dest' && sudo rm -f '$remote_tar'"
                else
                    extract_cmd="mkdir -p '$remote_dest' && tar -xzf '$remote_tar' -C '$remote_dest' && rm -f '$remote_tar'"
                fi

                # [LOGIC] -t allocates a pseudo-TTY so that sudo can prompt for a
                # password interactively when needed (system paths)
                lx cmd --run "ssh -t $USER_OBSERVER@$ip '$extract_cmd'" \
                       --error-msg "Extraction failed for $remote_dest"

                output --ok "Deployed directory: $remote_dest"

                # Directory deployments are fully handled — skip the single-file steps below
                continue
            fi

            # ==================================================================
            # --- Single File Deploy (Two-Step: rsync to /tmp, then move) ---
            # We never rsync directly to the final path because:
            #  a) system paths require sudo — rsync cannot sudo
            #  b) rsync as fadmin to /etc/ would be permission-denied
            # Solution: rsync to /tmp (fadmin-writable), then sudo mv to final dest.
            # ==================================================================

            # Unique tmp path on the remote to hold the file before it is moved
            local remote_tmp="/tmp/lpex_obs_$(basename "$file_path")"

            # Step 1: Transfer the file to the fadmin-writable /tmp on the Pi
            output --info "-> Transferring to $node:/tmp..."
            if ! lx cmd --run "rsync -avz '$abs_file' $USER_OBSERVER@$ip:'$remote_tmp'" \
                    --quiet --error-msg "rsync failed"; then
                continue
            fi

            # Step 2: Move from /tmp to the final destination
            if (( needs_sudo )); then
                output --info "-> Moving to system path via sudo..."

                # Build the move command: ensure parent dir exists, then move
                local mv_cmd="sudo mkdir -p '$remote_parent' && sudo mv '$remote_tmp' '$remote_dest'"

                # [LOGIC] Chain daemon-reload for systemd units immediately after
                # the file is placed so the new unit definition is picked up by
                # systemd without requiring a manual "systemctl daemon-reload".
                if (( is_systemd )); then
                    mv_cmd="$mv_cmd && sudo systemctl daemon-reload"
                    output --info "-> Triggering daemon-reload..."
                fi

                # [LOGIC] -t allocates a pseudo-TTY for interactive sudo password prompts.
                # Without -t, sudo would silently fail if a password is required.
                lx cmd --run "ssh -t $USER_OBSERVER@$ip '$mv_cmd'" \
                       --error-msg "sudo move failed for $remote_dest"
            else
                # No sudo needed — plain mkdir + mv as fadmin
                lx cmd --run "ssh $USER_OBSERVER@$ip 'mkdir -p \"$remote_parent\" && mv \"$remote_tmp\" \"$remote_dest\"'" \
                       --quiet --error-msg "Move failed for $remote_dest"
            fi

            # Step 3: Set execute permission for shell scripts
            # [LOGIC] The source file may lack +x (e.g. freshly created with touch).
            # We set it explicitly here so the script is immediately runnable on the Pi.
            if (( is_script )); then
                local chmod_cmd="chmod +x '$remote_dest'"
                # Use sudo if the file lives in a system-owned directory
                (( needs_sudo )) && chmod_cmd="sudo $chmod_cmd"
                lx cmd --run "ssh $USER_OBSERVER@$ip '$chmod_cmd'" \
                       --quiet --error-msg "chmod +x failed for $remote_dest"
            fi

            output --ok "Deployed: $remote_dest"
        done
    done
}

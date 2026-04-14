#!/bin/bash
# ==============================================================================
# @meta_module      : server observer push
# @meta_file        : main.sh
# @meta_date        : 2026-04-13
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
            # abs_file_base holds the global pool path when node-specific wins but
            # the global pool also has the same directory — used for the merge below.
            local abs_file_base=""
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
                # [LOGIC] For directories: if the global pool also has the same path,
                # record it as the base layer. It will be pushed first so the
                # node-specific version overlays it — specific files win on conflict.
                if [[ -d "$abs_file" && -d "$global_dir/$file_path" ]]; then
                    abs_file_base="$(realpath "$global_dir/$file_path")"
                    output --info "Matched node-specific payload (global base also present — will merge)."
                else
                    output --info "Matched node-specific payload."
                fi
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

            # [LOGIC] Any path under /etc, /usr, /lib, or /root requires root ownership.
            # We cannot write there as fadmin directly — sudo is required.
            # Systemd units (which live under /etc) are also covered by this check.
            [[ "$remote_dest" == /etc/* || "$remote_dest" == /usr/* || "$remote_dest" == /lib/* || "$remote_dest" == /root/* ]] && needs_sudo=1
            # Explicitly also set needs_sudo for systemd units in case they are placed elsewhere
            (( is_systemd )) && needs_sudo=1
            # [LOGIC] Full tree-mirror push ("/") always requires sudo — the tarball may
            # contain files under /root/, /etc/, /usr/ or other system-owned paths.
            # We cannot know the content ahead of time, so we must always use sudo here.
            [[ "$remote_dest" == "/" ]] && needs_sudo=1

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

                # [LOGIC] Prompt for confirmation before a full root push ("/") once,
                # before any layer is transferred, to avoid partial state on abort.
                if [[ "$remote_dest" == "/" ]]; then
                    output --warn "About to extract the ENTIRE tree-mirror to / on $node."
                    output --warn "Existing files will be overwritten. Remote-only files are NOT deleted."
                    if ! question "Continue with full tree-mirror push to $node?" --default-no; then
                        output --info "Aborted."
                        continue
                    fi
                fi

                # Build ordered push list: global base first, node-specific overlay second.
                # Mode A and global-only cases produce a single-element list.
                local -a dir_push_list=()
                [[ -n "$abs_file_base" ]] && dir_push_list+=("$abs_file_base")
                dir_push_list+=("$abs_file")

                local dir_total=${#dir_push_list[@]}
                local dir_idx=0
                local dir_push_failed=0

                for src_dir in "${dir_push_list[@]}"; do
                    dir_idx=$(( dir_idx + 1 ))
                    [[ $dir_total -gt 1 ]] && output --info "-> Layer $dir_idx/$dir_total: $(basename "$src_dir")"

                    # [LOGIC] -C changes into the source directory first so that tar
                    # packs the *contents* rather than the directory itself.
                    local local_tar="/tmp/lpex_obs_push_${node}_$(basename "$src_dir")_${dir_idx}.tar.gz"
                    local remote_tar="/tmp/lpex_obs_push_${node}_$(basename "$src_dir")_${dir_idx}.tar.gz"

                    # ==============================================================
                    # OWNERSHIP STRATEGY
                    # ==============================================================
                    # Pushing files with the local user's UID (e.g. 1000 = florian)
                    # archived into the tarball is always wrong on the remote:
                    #   - System paths (/etc, /usr) must be owned by root.
                    #   - fadmin paths (/home/fadmin) must be owned by fadmin.
                    #   - The local UID "florian" exists on neither target.
                    #
                    # For non-"/" directory pushes, the target is either always a
                    # system path (needs_sudo=1 → root) or always a fadmin path
                    # (needs_sudo=0 → fadmin). We can use a single tar ownership.
                    #
                    # For the full tree-mirror push ("/"), the tarball contains BOTH
                    # system paths AND /home/fadmin. A single ownership override
                    # cannot serve both. If we use --owner=root here, /home/fadmin
                    # ends up owned by root, breaking sshd StrictModes and key auth.
                    #
                    # FIX for remote_dest == "/": split into two sub-pushes:
                    #   1. home/ sub-tar  → --owner=fadmin:fadmin, extracted as fadmin
                    #   2. system sub-tar → --owner=root:root,   extracted via sudo
                    # ==============================================================

                    if [[ "$remote_dest" == "/" ]]; then
                        # --- Full tree-mirror push: split home vs. system tarballs ---

                        local split_failed=0

                        # ---- Sub-push 1: home/fadmin (fadmin ownership, no sudo) ----
                        if [[ -d "$src_dir/home" ]]; then
                            local local_tar_home="${local_tar%.tar.gz}_home.tar.gz"
                            local remote_tar_home="${remote_tar%.tar.gz}_home.tar.gz"

                            output --info "-> [home/] Packing with fadmin ownership..."
                            if ! tar --owner="$USER_OBSERVER" --group="$USER_OBSERVER" \
                                    -czf "$local_tar_home" -C "$src_dir" ./home; then
                                output --error "Failed to create home tarball (layer $dir_idx)."
                                split_failed=1
                            else
                                if ! lx cmd --run "rsync -avz '$local_tar_home' $USER_OBSERVER@$ip:'$remote_tar_home'" \
                                        --quiet --error-msg "rsync of home tarball failed"; then
                                    split_failed=1
                                else
                                    # Extract as fadmin — no sudo, fadmin-owned files stay fadmin-owned
                                    if ! lx cmd --run "ssh $USER_OBSERVER@$ip \
                                            'tar -xzf \"$remote_tar_home\" -C / && rm -f \"$remote_tar_home\"'" \
                                           --error-msg "Extraction of home/ failed"; then
                                        split_failed=1
                                    fi
                                fi
                                rm -f "$local_tar_home"
                            fi
                        fi

                        # ---- Sub-push 2: system paths (root ownership, sudo) ----
                        local -a sys_dirs=()
                        for d in "$src_dir"/*/; do
                            [[ -d "$d" ]] || continue
                            local dname
                            dname=$(basename "$d")
                            [[ "$dname" == "home" ]] && continue
                            sys_dirs+=("./$dname")
                        done

                        if [[ ${#sys_dirs[@]} -gt 0 ]]; then
                            local local_tar_sys="${local_tar%.tar.gz}_sys.tar.gz"
                            local remote_tar_sys="${remote_tar%.tar.gz}_sys.tar.gz"

                            output --info "-> [system/] Packing with root ownership..."
                            if ! tar --owner=root --group=root \
                                    -czf "$local_tar_sys" -C "$src_dir" "${sys_dirs[@]}"; then
                                output --error "Failed to create system tarball (layer $dir_idx)."
                                split_failed=1
                            else
                                if ! lx cmd --run "rsync -avz '$local_tar_sys' $USER_OBSERVER@$ip:'$remote_tar_sys'" \
                                        --quiet --error-msg "rsync of system tarball failed"; then
                                    split_failed=1
                                else
                                    if ! lx cmd --run "ssh -t $USER_OBSERVER@$ip \
                                            'sudo tar -xzf \"$remote_tar_sys\" -C / && sudo rm -f \"$remote_tar_sys\"'" \
                                           --error-msg "Extraction of system paths failed"; then
                                        split_failed=1
                                    fi
                                fi
                                rm -f "$local_tar_sys"
                            fi
                        fi

                        if (( split_failed )); then
                            dir_push_failed=1
                            break
                        fi

                        # Full-tree split handled — continue to next src_dir layer
                        continue
                    fi

                    # --- Normal (non-"/") directory push ---

                    # [LOGIC] No --owner flags needed in tar. Ownership is determined by
                    # the cp command on the remote, not by the archived UID:
                    #   sudo cp  → creates files as root:root  (system paths)
                    #   cp       → creates files as fadmin:fadmin (home paths)
                    # This is equivalent to the observed behaviour of sudo cp vs cp,
                    # and avoids any dependency on what UID was archived locally.
                    if ! tar -czf "$local_tar" -C "$src_dir" .; then
                        output --error "Failed to create local tarball (layer $dir_idx)."
                        dir_push_failed=1
                        break
                    fi

                    output --info "-> Transferring layer $dir_idx to $node:/tmp..."
                    if ! lx cmd --run "rsync -avz '$local_tar' $USER_OBSERVER@$ip:'$remote_tar'" \
                            --quiet --error-msg "rsync of tarball failed (layer $dir_idx)"; then
                        rm -f "$local_tar"
                        dir_push_failed=1
                        break
                    fi
                    rm -f "$local_tar"

                    output --info "-> Extracting layer $dir_idx at $remote_dest..."

                    # [LOGIC] Extract to a temp dir first, then cp to the final destination.
                    # sudo cp creates files as root:root; cp as fadmin creates fadmin:fadmin.
                    # -t allocates a pseudo-TTY so sudo can prompt interactively.
                    local remote_extract="/tmp/lpex_obs_extract_${node}_${dir_idx}_${RANDOM}"
                    local extract_cmd
                    if (( needs_sudo )); then
                        extract_cmd="mkdir -p '$remote_extract' && tar -xzf '$remote_tar' -C '$remote_extract' && rm -f '$remote_tar' && sudo mkdir -p '$remote_dest' && (cd '$remote_extract' && sudo cp -r . '$remote_dest/') && sudo rm -rf '$remote_extract'"
                    else
                        extract_cmd="mkdir -p '$remote_extract' && tar -xzf '$remote_tar' -C '$remote_extract' && rm -f '$remote_tar' && mkdir -p '$remote_dest' && (cd '$remote_extract' && cp -r . '$remote_dest/') && rm -rf '$remote_extract'"
                    fi

                    if ! lx cmd --run "ssh -t $USER_OBSERVER@$ip '$extract_cmd'" \
                           --error-msg "Extraction failed for $remote_dest (layer $dir_idx)"; then
                        dir_push_failed=1
                        break
                    fi
                done

                (( dir_push_failed )) && continue
                output --ok "Deployed directory: $remote_dest"

                # Directory deployments are fully handled — skip the single-file steps below
                continue
            fi

            # ==================================================================
            # --- Single File Deploy (Two-Step: rsync to /tmp, then cp) ---
            # We never rsync directly to the final path because:
            #  a) system paths require sudo — rsync cannot sudo
            #  b) rsync as fadmin to /etc/ would be permission-denied
            # Solution: rsync to /tmp (fadmin-writable), then cp to final dest.
            # sudo cp → root:root; cp as fadmin → fadmin:fadmin. mv is NOT used
            # because mv preserves the source ownership from /tmp (fadmin:fadmin),
            # which would be wrong for system paths that must be owned by root.
            # ==================================================================

            # Unique tmp path on the remote to hold the file before it is moved
            local remote_tmp="/tmp/lpex_obs_$(basename "$file_path")"

            # Step 1: Transfer the file to the fadmin-writable /tmp on the Pi
            output --info "-> Transferring to $node:/tmp..."
            if ! lx cmd --run "rsync -avz '$abs_file' $USER_OBSERVER@$ip:'$remote_tmp'" \
                    --quiet --error-msg "rsync failed"; then
                continue
            fi

            # Step 2: Copy from /tmp to the final destination (cp, not mv)
            if (( needs_sudo )); then
                output --info "-> Copying to system path via sudo..."

                # sudo cp creates the file as root:root regardless of /tmp source ownership
                local cp_cmd="sudo mkdir -p '$remote_parent' && sudo cp '$remote_tmp' '$remote_dest' && sudo rm -f '$remote_tmp'"

                # [LOGIC] Chain daemon-reload for systemd units immediately after
                # the file is placed so the new unit definition is picked up by
                # systemd without requiring a manual "systemctl daemon-reload".
                if (( is_systemd )); then
                    cp_cmd="$cp_cmd && sudo systemctl daemon-reload"
                    output --info "-> Triggering daemon-reload..."
                fi

                # [LOGIC] -t allocates a pseudo-TTY for interactive sudo password prompts.
                # Without -t, sudo would silently fail if a password is required.
                lx cmd --run "ssh -t $USER_OBSERVER@$ip '$cp_cmd'" \
                       --error-msg "sudo cp failed for $remote_dest"
            else
                # No sudo needed — cp as fadmin gives fadmin:fadmin ownership
                lx cmd --run "ssh $USER_OBSERVER@$ip 'mkdir -p \"$remote_parent\" && cp \"$remote_tmp\" \"$remote_dest\" && rm -f \"$remote_tmp\"'" \
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

#!/bin/bash
# ==============================================================================
# @meta_name        : update/_run.sh
# @desc_short       : Update execution logic — sourced by update/main.sh.
# ==============================================================================

# ==============================================================================
# --- _update_device ---
# @desc_short   : Runs update-os.sh (and optionally apply-patches.sh) on one device.
# @parameter    : $1 | type     | Device type (observer, host, container, vm)
# @parameter    : $2 | id       | Device ID
# @parameter    : $3 | dry_run  | "1" = dry-run only (show upgradable packages)
# @parameter    : $4 | patches  | "1" = also run apply-patches.sh after update
# ==============================================================================
function _update_device {
    local type="$1" id="$2" dry_run="${3:-0}" patches="${4:-0}"
    local name
    name=$(_device_name "$type" "$id" 2>/dev/null || echo "${type}_${id}")

    INFO "[$name] Starting update..."

    # Select command: dry-run shows upgradable packages only; full run calls update-os.sh
    local cmd_update
    if (( dry_run )); then
        cmd_update="apt list --upgradable 2>/dev/null | grep -v 'Listing...'"
    else
        cmd_update="/opt/homelab/bin/update/update-os.sh"
    fi

    # Run the update command on the target device
    if ! _run_on_device "$type" "$id" "$cmd_update"; then
        ERROR "[$name] Update failed."
        return 1
    fi

    # Run patch application if requested and not in dry-run mode
    if (( patches && !dry_run )); then
        INFO "[$name] Applying patches..."
        if ! _run_on_device "$type" "$id" "/opt/homelab/bin/update/apply-patches.sh"; then
            ERROR "[$name] Patch application failed."
            return 1
        fi
    fi

    OK "[$name] Update complete."
}

# ==============================================================================
# --- _update_all_observers ---
# @desc_short   : Updates all observers from homelab_conf.db sequentially.
# ==============================================================================
function _update_all_observers {
    local dry_run="${1:-0}" patches="${2:-0}"
    local -a obs_rows=()
    lx db --file "homelab_conf.db" --table "observers" --select @obs_rows \
        --cols "id" --sort "id ASC" 2>/dev/null

    # Abort if no observers are registered in the database
    if (( ${#obs_rows[@]} == 0 )); then
        WARN "No observers found in homelab_conf.db."
        return 0
    fi

    local any_error=0
    # Update each observer in order — continue on failure but track errors
    for row in "${obs_rows[@]}"; do
        _update_device "observer" "$row" "$dry_run" "$patches" || any_error=1
    done
    (( any_error )) && return 1
    return 0
}

# ==============================================================================
# --- _update_all_hosts ---
# @desc_short   : Updates all hosts from homelab_conf.db sequentially.
# ==============================================================================
function _update_all_hosts {
    local dry_run="${1:-0}" patches="${2:-0}"
    local -a host_rows=()
    lx db --file "homelab_conf.db" --table "hosts" --select @host_rows \
        --cols "id" --sort "id ASC" 2>/dev/null

    # Abort if no hosts are registered in the database
    if (( ${#host_rows[@]} == 0 )); then
        WARN "No hosts found in homelab_conf.db."
        return 0
    fi

    local any_error=0
    # Update each host in order — continue on failure but track errors
    for row in "${host_rows[@]}"; do
        _update_device "host" "$row" "$dry_run" "$patches" || any_error=1
    done
    (( any_error )) && return 1
    return 0
}

# ==============================================================================
# --- _update_all_clients ---
# @desc_short   : Updates all containers from NFS live files sequentially.
# ==============================================================================
function _update_all_clients {
    local dry_run="${1:-0}" patches="${2:-0}"
    local any_error=0 found=0

    # Iterate live files from all known hosts
    local live_file
    for live_file in "${PATH_SHARE_STATE}/hosts"/*/lxc-live.txt; do
        # Skip if live file does not exist
        [[ -f "$live_file" ]] || continue

        # Process each container listed in this host's live file
        while IFS= read -r line; do
            # Skip empty lines
            [[ -z "$line" ]] && continue
            local ctid
            ctid=$(echo "$line" | awk '{print $1}')
            (( found++ ))
            _update_device "container" "$ctid" "$dry_run" "$patches" || any_error=1
        done < "$live_file"
    done

    # Warn if no containers were found anywhere
    if (( found == 0 )); then
        WARN "No containers found in NFS live files (NFS may not be mounted)."
    fi

    (( any_error )) && return 1
    return 0
}

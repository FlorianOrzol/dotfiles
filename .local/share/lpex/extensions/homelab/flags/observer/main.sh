#!/bin/bash
# ==============================================================================
# @meta_name        : flags/observer/main.sh
# @desc_short       : Manages unit-skip and zfs-sync flags on an observer via SSH.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short   : Validates arguments and routes to the correct flag action.
# ==============================================================================
function extension_start {
    if [[ -z "$ARG_ID" ]]; then
        ERROR "No observer ID specified."
        return 1
    fi

    if [[ -z "$ARG_UNIT_SKIP" && -z "$ARG_ZFS_SYNC" && -z "$ARG_LIST" ]]; then
        ERROR "Specify a flag type: --unit-skip <unit>, --zfs-sync <host>, or --list."
        return 1
    fi

    if [[ -n "$ARG_UNIT_SKIP" && -n "$ARG_ZFS_SYNC" ]]; then
        ERROR "--unit-skip and --zfs-sync are mutually exclusive."
        return 1
    fi

    if [[ -n "$ARG_LIST" ]];      then action_list;      return $?; fi
    if [[ -n "$ARG_UNIT_SKIP" ]]; then action_unit_skip; return $?; fi
    if [[ -n "$ARG_ZFS_SYNC" ]];  then action_zfs_sync;  return $?; fi
}

# ==============================================================================
# --- action_list ---
# @desc_short   : Lists all active flags on the observer (unit-skip + zfs-sync).
# ==============================================================================
function action_list {
    local id="$ARG_ID"
    INFO "Listing flags on observer ${id}..."

    local cmd_skip="echo '--- unit-skip flags ---'; \
        ls /opt/homelab/state/flags/unit_skip/ 2>/dev/null || echo '(none)'"

    local cmd_zfs="echo '--- zfs-sync flags ---'; \
        for f in /opt/homelab/state/flags/allow_zfs_sync_*; do \
            [[ -f \"\$f\" ]] || continue; \
            echo \"\$(basename \$f): \$(cat \$f)\"; \
        done || echo '(none)'"

    run_on_observer "$id" "${cmd_skip}; ${cmd_zfs}"
}

# ==============================================================================
# --- action_unit_skip ---
# @desc_short   : Sets or removes a unit-skip flag on the observer.
# ==============================================================================
function action_unit_skip {
    local id="$ARG_ID" unit="$ARG_UNIT_SKIP"

    if [[ -z "$ARG_SET" && -z "$ARG_REMOVE" ]]; then
        ERROR "Specify --set or --remove for --unit-skip."
        return 1
    fi

    if [[ -n "$ARG_SET" && -n "$ARG_REMOVE" ]]; then
        ERROR "--set and --remove are mutually exclusive."
        return 1
    fi

    local flag_path="/opt/homelab/state/flags/unit_skip/${unit}"
    local reason="${ARG_REASON:-manual via lpex}"

    if [[ -n "$ARG_REMOVE" ]]; then
        INFO "Removing unit-skip flag: ${unit} on observer ${id}..."
        if ! run_on_observer "$id" "rm -f '${flag_path}'"; then
            ERROR "Failed to remove flag: ${flag_path}"
            return 1
        fi
        OK "unit-skip flag removed: ${unit}"
        return 0
    fi

    if [[ -n "$ARG_SET" ]]; then
        INFO "Setting unit-skip flag: ${unit} on observer ${id}..."
        local json
        json=$(printf '{"reason":"%s","set_by":"lpex"}' "$reason")
        local cmd="mkdir -p '$(dirname "$flag_path")' && echo '${json}' > '${flag_path}'"
        if ! run_on_observer "$id" "$cmd"; then
            ERROR "Failed to set flag: ${flag_path}"
            return 1
        fi
        OK "unit-skip flag set: ${unit} (reason: ${reason})"
    fi
}

# ==============================================================================
# --- action_zfs_sync ---
# @desc_short   : Enables or disables the ZFS sync flag for a specific host.
# ==============================================================================
function action_zfs_sync {
    local id="$ARG_ID" host_name="$ARG_ZFS_SYNC"

    if [[ -z "$ARG_ON" && -z "$ARG_OFF" ]]; then
        ERROR "Specify --on or --off for --zfs-sync."
        return 1
    fi

    if [[ -n "$ARG_ON" && -n "$ARG_OFF" ]]; then
        ERROR "--on and --off are mutually exclusive."
        return 1
    fi

    local flag_path="/opt/homelab/state/flags/allow_zfs_sync_${host_name}"

    if [[ -n "$ARG_ON" ]]; then
        INFO "Enabling ZFS sync for ${host_name} on observer ${id}..."
        if ! run_on_observer "$id" "echo '1' > '${flag_path}'"; then
            ERROR "Failed to enable zfs-sync flag for ${host_name}"
            return 1
        fi
        OK "ZFS sync enabled for ${host_name} (allow_zfs_sync_${host_name}=1)"
        return 0
    fi

    if [[ -n "$ARG_OFF" ]]; then
        INFO "Disabling ZFS sync for ${host_name} on observer ${id}..."
        if ! run_on_observer "$id" "echo '0' > '${flag_path}'"; then
            ERROR "Failed to disable zfs-sync flag for ${host_name}"
            return 1
        fi
        WARN "ZFS sync disabled for ${host_name} (allow_zfs_sync_${host_name}=0)"
        WARN "Re-enable after verifying: lpex homelab flags observer ${id} --zfs-sync ${host_name} --on"
    fi
}

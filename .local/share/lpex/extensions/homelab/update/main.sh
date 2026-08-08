#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Entry point for 'homelab update' — expands the requested
#                     target groups/devices, optionally wakes offline targets,
#                     then updates each target sequentially.
# ==============================================================================

source "${PATH_EXTENSION}/_targets.sh"
source "${PATH_EXTENSION}/_run.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates the device selection, expands groups into concrete
#                targets and runs wake-up and update per target.
# ==============================================================================
function extension_start {
    # At least one target group or device is required.
    if (( ${#ARG_DEVICES[@]} == 0 )); then
        ERROR "No devices specified. Use --devices <all|hosts|observers|clients|host_1|ct_3040|...>."
        return 1
    fi

    # Expand groups (all, hosts, observers, clients) and validate device names
    # into deduplicated "type:device" pairs.
    local -a targets=()
    collect_targets @targets "${ARG_DEVICES[@]}" || return 1

    INFO "Resolved targets: ${targets[*]}"

    local target type device any_error=0
    for target in "${targets[@]}"; do
        # Split "type:device" pair — %% strips from first colon to end for type,
        # # strips up to and including first colon for device.
        type="${target%%:*}"
        device="${target#*:}"

        # Wake offline targets first — skip the update when waking fails.
        # was_offline records whether this run started the device, so its previous
        # power state can be restored below.
        local was_offline=0
        if (( ARG_WAKE_UP )); then
            wake_target @was_offline "$type" "$device" || { any_error=1; continue; }
        fi

        # Track failure without stopping — all targets should be attempted.
        update_device "$type" "$device" "$ARG_DRY_RUN" "$ARG_REBOOT" "$ARG_REBOOT_FORCE" || any_error=1

        # Restore the pre-update power state for hosts this run woke up.
        if (( was_offline )); then
            # A requested reboot wins — shutting down now would kill the device
            # mid-boot, and the caller explicitly asked for it to come back up.
            if [[ -n "$ARG_REBOOT" || -n "$ARG_REBOOT_FORCE" ]]; then
                WARN "[${device}] Woken for this update but stays online — a reboot was requested."
            else
                shutdown_woken_host "$device" || any_error=1
            fi
        fi
    done

    # Propagate failure if any wake-up or update failed.
    (( any_error )) && return 1
    return 0
}

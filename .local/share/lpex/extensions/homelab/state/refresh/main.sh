#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Entry point for 'homelab state refresh' — re-runs the health
#                     collectors so status.json on the share reflects the current
#                     state instead of the last timer run (06:05 / 06:10).
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Refreshes every reachable device, or only the requested targets.
# @notes       : Offline devices are skipped and keep their last known status —
#                collecting data must never power a device on. --wake-up is the
#                only way to start one, and it restores the previous power state.
# ==============================================================================
function extension_start {
    # No explicit target is the common case: sweep everything that answers a ping.
    if (( ${#ARG_DEVICES[@]} == 0 )); then
        INFO "Refreshing status of all reachable devices..."
        refresh_all_status
        return 0
    fi

    # Expand groups (all, hosts, observers, clients) and validate device names
    # into deduplicated "type:device" pairs — same grammar as 'homelab update'.
    local -a targets=()
    collect_targets @targets "${ARG_DEVICES[@]}" || return 1

    INFO "Resolved targets: ${targets[*]}"

    local target type device any_error=0
    for target in "${targets[@]}"; do
        # Split "type:device" pair — %% strips from first colon to end for type,
        # # strips up to and including first colon for device.
        type="${target%%:*}"
        device="${target#*:}"

        # was_offline records whether this run started the device, so its previous
        # power state can be restored below.
        local was_offline=0
        if (( ARG_WAKE_UP )); then
            # Waking was asked for explicitly — skip the target when it fails.
            wake_target @was_offline "$type" "$device" || { any_error=1; continue; }
        elif [[ "$type" == "host" || "$type" == "observer" ]]; then
            # Only named nodes can be probed by IP; clients are handled by their host.
            if ! device_is_online "$device"; then
                INFO "[${device}] Offline — skipped, status on the share stays as it is."
                continue
            fi
        fi

        refresh_device_status "$type" "$device"

        # Restore the pre-refresh power state for hosts this run woke up.
        if (( was_offline )); then
            shutdown_woken_host "$device" || any_error=1
        fi
    done

    # Propagate failure if any wake-up or power-down failed.
    (( any_error )) && return 1
    return 0
}

#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Entry point for 'homelab update' — expands the requested
#                     target groups/devices, optionally wakes offline targets,
#                     updates each target sequentially, awaits requested reboots,
#                     restores the pre-update power state and prints a summary.
# ==============================================================================

source "${PATH_EXTENSION}/_run.sh"
source "${PATH_EXTENSION}/_power.sh"
source "${PATH_EXTENSION}/_summary.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates the device selection, expands groups into concrete
#                targets and runs wake-up, update, reboot wait, status refresh
#                and power-state restore per target.
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

    # Updated devices are refreshed by default — the daily health timer (06:05)
    # would otherwise show stale pre-update data until the next morning. A dry-run
    # changes nothing, so there it only happens when explicitly asked for.
    local do_refresh=1
    if [[ -n "$ARG_DRY_RUN" && -z "$ARG_STATUS_REFRESH" && -z "$ARG_STATUS_REFRESH_ALL" ]]; then
        do_refresh=0
    fi

    # A reboot is only ever requested for real updates — a dry-run changes nothing
    local want_reboot=0
    if [[ -z "$ARG_DRY_RUN" && ( -n "$ARG_REBOOT" || -n "$ARG_REBOOT_FORCE" ) ]]; then
        want_reboot=1
    fi

    # Record every client's power state before anything changes — the reference
    # for restoring it at the end (a host reboot stops all non-HA clients)
    local -A power_before=()
    snapshot_client_power @power_before
    _summary_register_targets @power_before "${targets[@]}"

    local target type device label any_error=0 rc
    local -a refreshed=() woken_clients=()
    for target in "${targets[@]}"; do
        # Split "type:device" pair — %% strips from first colon to end for type,
        # # strips up to and including first colon for device.
        type="${target%%:*}"
        device="${target#*:}"
        label=$(target_label "$type" "$device")

        # 1. --- Wake-up ---------------
        # ------ was_offline records whether this run started the device, so its
        # ------ previous power state can be restored afterwards.
        local was_offline=0
        if (( ARG_WAKE_UP )); then
            if ! wake_target @was_offline "$type" "$device"; then
                SUMMARY_UPDATE["$label"]="skipped (wake failed)"
                any_error=1
                continue
            fi
            # Clients are restored in one pass after all updates
            if (( was_offline )) && [[ "$type" == "container" || "$type" == "vm" ]]; then
                woken_clients+=("${type}:${device}")
            fi
        fi

        # 2. --- Update ---------------
        # ------ The boot token taken before the update tells a finished reboot apart
        # ------ from a device that simply still runs.
        local boot_token=""
        (( want_reboot )) && boot_token=$(get_boot_token "$type" "$device")

        update_device "$type" "$device" "$ARG_DRY_RUN" "$ARG_REBOOT" "$ARG_REBOOT_FORCE"
        rc=$?
        # Map the result to the summary — a missing script is a gap, not a failure
        case "$rc" in
            0) [[ -n "$ARG_DRY_RUN" ]] && SUMMARY_UPDATE["$label"]="dry-run" || SUMMARY_UPDATE["$label"]="ok" ;;
            2) SUMMARY_UPDATE["$label"]="no script" ;;
            *) SUMMARY_UPDATE["$label"]="FAILED"; any_error=1 ;;
        esac

        # 3. --- Reboot wait + post-reboot check ---------------
        # ------ Waiting right here keeps the order safe: observer_1 is the wake
        # ------ authority and host_1 carries the clients updated later.
        local reboot_ok=1
        if (( rc == 0 && want_reboot )) && [[ -n "$boot_token" ]]; then
            _handle_reboot "$type" "$device" "$label" "$boot_token" || { reboot_ok=0; any_error=1; }
        elif (( rc == 0 && want_reboot )); then
            # VMs and stopped clients deliver no boot token — reboot cannot be tracked
            SUMMARY_REBOOT["$label"]="not tracked"
        fi

        # 4. --- Status refresh ---------------
        # ------ After the reboot wait, so the share shows the post-reboot state.
        if (( rc == 0 && do_refresh && reboot_ok )); then
            refresh_device_status "$type" "$device"
            # Hosts and observers were collected completely — a sweep can skip them.
            if [[ "$type" == "host" || "$type" == "observer" ]]; then
                refreshed+=("$device")
            fi
        fi

        # 5. --- Restore host power state ---------------
        # ------ A host woken for this run goes down again — also after a reboot,
        # ------ which is complete and checked by now. An unfinished reboot leaves
        # ------ the host alone: shutting down mid-boot would be worse than running.
        if (( was_offline )) && [[ "$type" == "host" ]]; then
            if (( reboot_ok )); then
                shutdown_woken_host "$device" || any_error=1
            else
                WARN "[${device}] Woken for this update but stays online — its reboot did not complete."
            fi
        fi
    done

    # Restore clients: stop the ones woken only for this run, restart the ones a
    # host reboot took down. Runs after all updates — a later host reboot in the
    # same run would otherwise undo it.
    lx output --section "Restoring pre-update power state"
    restore_client_power @power_before "${woken_clients[@]}" || any_error=1

    # --status-refresh-all widens the scope from the updated devices to every
    # device that answers a ping. Offline ones keep their last known status —
    # they are never woken just to be read.
    if [[ -n "$ARG_STATUS_REFRESH_ALL" ]]; then
        INFO "Refreshing status of all reachable devices..."
        refresh_all_status "${refreshed[@]}"
    fi

    # Final table — every target with before/after state and all results at a glance
    summary_fill_after "${targets[@]}"
    summary_print

    # Propagate failure if any wake-up, update, reboot or restore failed.
    (( any_error )) && return 1
    return 0
}

# --- _summary_register_targets ---
# @desc_short  : Adds every target with its pre-update power state to the summary.
# @usage       : _summary_register_targets @snapshot <type:device>...
# @parameter   : $1 | snapshot | Associative array from snapshot_client_power
# @parameter   : $@ | targets  | "type:device" pairs
# ==============================================================================
function _summary_register_targets {
    local snapshot_name="${1#@}"
    shift
    local target type device label before

    # Nodes are probed by ping, clients looked up in the snapshot
    for target in "$@"; do
        type="${target%%:*}"
        device="${target#*:}"
        label=$(target_label "$type" "$device")
        case "$type" in
            host|observer) device_is_online "$device" && before="online" || before="offline" ;;
            *)             before=$(client_power_label "@${snapshot_name}" "$type" "$device") ;;
        esac
        summary_add "$label" "$before"
    done
}

# --- _handle_reboot ---
# @desc_short  : Detects a scheduled reboot, waits for it and checks the device.
# @usage       : _handle_reboot <type> <device> <label> <boot_token_before>
# @exit_codes  : 0 | No reboot needed, or reboot completed.
# @exit_codes  : 1 | Reboot did not complete within TIMEOUT_REBOOT_WAIT.
# ==============================================================================
function _handle_reboot {
    local type="$1" device="$2" label="$3" boot_token="$4"
    local seconds_reboot verdict

    # --reboot only reboots when the system demands it — nothing to wait for otherwise
    if ! reboot_scheduled "$type" "$device" "$boot_token"; then
        SUMMARY_REBOOT["$label"]="not needed"
        return 0
    fi

    # Block until the device is back — later targets may depend on it
    if ! await_reboot @seconds_reboot "$type" "$device" "$boot_token"; then
        SUMMARY_REBOOT["$label"]="TIMEOUT"
        return 1
    fi
    SUMMARY_REBOOT["$label"]="done (${seconds_reboot}s)"

    # Does everything run after the reboot, and which errors did the boot log?
    post_reboot_check @verdict "$type" "$device"
    SUMMARY_CHECK["$label"]="$verdict"
    return 0
}

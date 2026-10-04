#!/bin/bash
# ==============================================================================
# @meta_name        : _run.sh
# @desc_short       : Update execution logic — sourced by update/main.sh.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
CMD_DRY_RUN="apt list --upgradable 2>/dev/null | grep -v Listing || echo no upgradable packages"  # lists upgradable packages; echo-fallback — grep exits 1 on empty list which is not an error; no quotes in pattern — cmd is wrapped in single quotes for SSH
CMD_UPDATE="/opt/homelab/bin/update/update-os.sh"                       # runs full OS update (apt dist-upgrade)

# ==============================================================================
# --- update_device ---
# @desc_short  : Runs update (or dry-run) on a single device.
# @notes       : Patches (apply-patches.sh) are intentionally not wired here —
#                they belong to the planned 'setup patches' submodule.
#                The status refresh is owned by extension_start — it decides the
#                scope (affected devices vs. full sweep) for the whole run.
# @parameter   : $1 | type         | Device type: observer | host | container | vm
# @parameter   : $2 | device       | Device name or ID
# @parameter   : $3 | dry_run      | Non-empty = show upgradable packages only, no changes
# @parameter   : $4 | reboot       | Non-empty = reboot the device when apt demands it
# @parameter   : $5 | reboot_force | Non-empty = reboot the device unconditionally
# @exit_codes  : 0 | Update (or dry-run) succeeded.
# @exit_codes  : 1 | Update failed.
# @exit_codes  : 2 | Skipped — the container has no update-os.sh deployed.
# ==============================================================================
function update_device {
    local type="$1" device="$2" dry_run="$3" reboot="$4" reboot_force="$5"
    local cmd_update

    INFO "[${device}] Starting update..."

    # Containers only get update-os.sh with their mirror — without it the update
    # cannot run, which is a deployment gap and not an update failure
    if [[ -z "$dry_run" && "$type" == "container" ]] && ! _container_has_update_script "$device"; then
        WARN "[ct_${device}] No ${CMD_UPDATE} deployed — skipped."
        return 2
    fi

    # Dry-run only lists upgradable packages without touching the system.
    # Full run calls update-os.sh which runs apt update + apt dist-upgrade;
    # --reboot-force schedules a delayed reboot unconditionally (wins over
    # --reboot), --reboot only when apt demands one.
    if [[ -n "$dry_run" ]]; then
        cmd_update="$CMD_DRY_RUN"
    elif [[ -n "$reboot_force" ]]; then
        cmd_update="${CMD_UPDATE} --reboot-force"
    elif [[ -n "$reboot" ]]; then
        cmd_update="${CMD_UPDATE} --reboot"
    else
        cmd_update="$CMD_UPDATE"
    fi

    # Abort with a clear error if the update command fails.
    if ! _execute_update "$type" "$device" "$cmd_update"; then
        ERROR "[${device}] Update failed."
        return 1
    fi

    OK "[${device}] Update complete."
    return 0
}

# --- _execute_update ---
# @desc_short  : Dispatches a shell command to the correct execute helper by device type.
# @parameter   : $1 | type   | Device type: observer | host | container | vm
# @parameter   : $2 | device | Device name or ID
# @parameter   : $3 | cmd    | Command to execute on the target device
# ==============================================================================
function _execute_update {
    local type="$1" device="$2" cmd="$3"

    # Route to the correct helper — containers and VMs require indirection via their host.
    # Observers SSH as fadmin — apt and the update scripts need sudo there;
    # hosts SSH as root, containers/VMs execute as root via pct/qm.
    case "$type" in
        observer)      execute_on_device    "$device" "sudo ${cmd}" ;;
        host)          execute_on_device    "$device" "$cmd" ;;
        container)     execute_on_container "$device" "$cmd" ;;
        vm)            execute_on_vm        "$device" "$cmd" ;;
        # Unknown type indicates a bug in the caller — surface it immediately.
        *)             ERROR "Unknown device type: '${type}'"; return 1 ;;
    esac
}

# --- _container_has_update_script ---
# @desc_short  : Returns 0 when the running container has update-os.sh installed.
# @usage       : _container_has_update_script <container_id>
# @notes       : A stopped container counts as "has script" — the update then fails
#                with its own clear error instead of being reported as a gap.
# ==============================================================================
function _container_has_update_script {
    local container_id="$1"
    local answer

    # Probe inside the running instance — prints yes/no, nothing when not running
    answer=$(run_script_on_target "container" "$container_id" "test -x ${CMD_UPDATE} && echo yes || echo no")
    [[ "$answer" != "no" ]]
}

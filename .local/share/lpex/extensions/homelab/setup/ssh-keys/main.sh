#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates arguments and routes to ssh-keys setup actions.
# ==============================================================================

source "${PATH_EXTENSION}/_deploy.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Collects all selected devices, validates that at least one
#                device and one action were given, then runs the action(s) on
#                each device in turn.
# @notes       : Devices from all four types are merged into one list so the
#                loop body stays uniform regardless of device type.
#                Multiple action flags are allowed — both run in order.
# ==============================================================================
function extension_start {
    local any_error=0
    local -a all_targets=()

    # Collect selected physical nodes as "type:name" pairs into one list.
    # Clients (container/vm) are excluded — they self-initialize via ct-ssh-init.sh.
    for device in "${ARG_HOST[@]}";     do all_targets+=("host:${device}");     done
    for device in "${ARG_OBSERVER[@]}"; do all_targets+=("observer:${device}"); done

    # Require at least one device — nothing to act on otherwise.
    if (( ${#all_targets[@]} == 0 )); then
        ERROR "No device specified. Use --host or --observer."
        return 1
    fi

    # Require at least one action flag.
    if [[ -z "${ARG_DEPLOY}${ARG_KNOWN_HOSTS}" ]]; then
        ERROR "No action specified. Use --deploy or --known-hosts."
        return 1
    fi

    # Iterate all selected devices and run the flagged action(s) on each.
    for target in "${all_targets[@]}"; do
        # Split "type:name" into separate variables.
        local device_type="${target%%:*}"
        local device_name="${target#*:}"

        # Run flagged actions in order — multiple flags are allowed.
        [[ -n "$ARG_DEPLOY" ]]      && { action_deploy      "$device_type" "$device_name" "$ARG_FORCE" || any_error=1; }
        [[ -n "$ARG_KNOWN_HOSTS" ]] && { action_known_hosts "$device_type" "$device_name"              || any_error=1; }
    done

    # Propagate failure if any action on any device failed.
    (( any_error )) && return 1
    return 0
}

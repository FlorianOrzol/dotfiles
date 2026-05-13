#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates arguments and routes to update actions.
# ==============================================================================

source "${PATH_EXTENSION}/_run.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Collects all selected devices into one array, validates that at
#                least one was given, then iterates and updates each device.
# ==============================================================================
function extension_start {
    local -a all_targets=()
    local any_error=0

    # Collect all selected devices into a single array as "type:device" pairs.
    # Each ARG_* is an array when --multi is used — the for loop handles 0..n entries.
    for host      in "${ARG_HOST[@]}";      do all_targets+=("host:${host}");           done
    for observer  in "${ARG_OBSERVER[@]}";  do all_targets+=("observer:${observer}");   done
    for container in "${ARG_CONTAINER[@]}"; do all_targets+=("container:${container}"); done
    for vm        in "${ARG_VM[@]}";        do all_targets+=("vm:${vm}");               done

    # Require at least one device — nothing to update otherwise.
    if (( ${#all_targets[@]} == 0 )); then
        ERROR "Specify at least one device (--host, --observer, --container, --vm)."
        return 1
    fi

    # Iterate all collected targets sequentially and update each one.
    for target in "${all_targets[@]}"; do
        # Split "type:device" pair — %% strips from first colon to end for type,
        # # strips up to and including first colon for device.
        local type="${target%%:*}"
        local device="${target#*:}"
        # Track failure without stopping — all targets should be attempted.
        update_device "$type" "$device" "$ARG_DRY_RUN" "$ARG_PATCHES" || any_error=1
    done

    # Propagate failure if any update failed.
    (( any_error )) && return 1
    return 0
}

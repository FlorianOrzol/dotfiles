#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates arguments and starts the disk recovery workflow on
#                     the observer. Sourced helpers handle the SSH execution.
# ==============================================================================

source "${PATH_EXTENSION}/_run.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Applies defaults, validates args, launches recovery on observer.
# ==============================================================================
function extension_start {
    # Default observer to primary if not specified — most common case
    local observer="${ARG_OBSERVER:-${OBSERVER_PRIMARY}}"

    # Validate observer name — catch typos before SSH attempt
    if ! get_device_ip "$observer" &>/dev/null; then
        ERROR "Unknown observer: '${observer}'"
        return 1
    fi

    action_run_recovery \
        "$observer" \
        "$ARG_TARGET" \
        "$ARG_SOURCE" \
        "$ARG_POOL" \
        "$ARG_DISK" \
        "$ARG_YES"
}

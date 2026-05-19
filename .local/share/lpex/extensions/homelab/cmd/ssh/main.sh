#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Executes an ad-hoc command on a remote device via SSH.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# ==============================================================================
function extension_start {
    # Validate required arguments
    [[ -z "$ARG_CMD" ]]    && { ERROR "No command specified."; return 1; }
    [[ -z "$ARG_DEVICE" ]] && { ERROR "No device specified.";  return 1; }

#    INFO "Running command on '${ARG_DEVICE}'..."
    execute_on_device "$ARG_DEVICE" "${ARG_CMD[*]}"
}

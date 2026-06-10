#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Executes an ad-hoc command on a remote device via SSH.
#                     Routes to the correct execution method based on device type prefix.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates arguments and routes the command to the correct device type.
# ==============================================================================
function extension_start {
    # Both device and command are required.
    [[ -z "$ARG_DEVICE" ]] && { ERROR "No device specified.";  return 1; }
    [[ -z "$ARG_CMD"    ]] && { ERROR "No command specified."; return 1; }

    local cmd="${ARG_CMD[*]}"

    # Route to the correct execute helper based on the device type prefix.
    case "$ARG_DEVICE" in
        ct_*)
            # Strip prefix — execute_on_container expects the numeric ID only.
            local container_id="${ARG_DEVICE#ct_}"
            execute_on_container "$container_id" "$cmd"
            ;;
        vm_*)
            # Strip prefix — execute_on_vm expects the numeric ID only.
            local vm_id="${ARG_DEVICE#vm_}"
            execute_on_vm "$vm_id" "$cmd"
            ;;
        *)
            # Hosts and observers — direct SSH via execute_on_device.
            execute_on_device "$ARG_DEVICE" "$cmd"
            ;;
    esac
}

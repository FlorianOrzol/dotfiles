#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Pushes the full local mirror of a device to that device.
#                     Device name is resolved to its mirror root path, then all
#                     content is transferred via the appropriate push method.
# ==============================================================================

source "${PATH_EXTENSION_SOURCE}/homelab/setup/files/_common.sh"
source "${PATH_EXTENSION_SOURCE}/homelab/setup/files/_push.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Resolves device name to mirror path and triggers the push.
# ==============================================================================
function extension_start {
    # Device name is required to determine what to push.
    [[ -z "$ARG_DEVICE" ]] && { ERROR "No device specified."; return 1; }

    local mirror_path

    # Resolve device name (e.g. ct_3040, host_1) to its local mirror root path.
    resolve_device_to_mirror_path "$ARG_DEVICE" mirror_path || return 1

    # Delegate to the shared push logic — pass device explicitly for unified mirror types.
    action_push "$mirror_path" "$ARG_DEVICE"
}

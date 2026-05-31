#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Generates and activates systemd units in a VM.
# ==============================================================================

function extension_start {
    [[ -z "$ARG_DEVICE" ]] && { ERROR "No VM specified."; return 1; }

    INFO "Generating units on VM '${ARG_DEVICE}'..."
    execute_on_vm "$ARG_DEVICE" "/opt/homelab/systemd/generate-units.sh" || return 1
    OK "Units generated and activated on VM '${ARG_DEVICE}'."
}

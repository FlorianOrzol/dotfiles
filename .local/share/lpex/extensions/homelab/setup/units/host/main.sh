#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Generates and activates systemd units on a host.
#                     Runs generate-units.sh directly via SSH (root — no sudo).
# ==============================================================================

function extension_start {
    [[ -z "$ARG_DEVICE" ]] && { ERROR "No host specified."; return 1; }

    INFO "Generating units on host '${ARG_DEVICE}'..."
    execute_on_device "$ARG_DEVICE" "/opt/homelab/systemd/generate-units.sh" || return 1
    OK "Units generated and activated on '${ARG_DEVICE}'."
}

#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Generates and activates systemd units on an observer.
#                     Runs generate-units.sh via SSH (fadmin — sudo required).
# ==============================================================================

function extension_start {
    [[ -z "$ARG_DEVICE" ]] && { ERROR "No observer specified."; return 1; }

    INFO "Generating units on observer '${ARG_DEVICE}'..."
    execute_on_device "$ARG_DEVICE" "sudo /opt/homelab/systemd/generate-units.sh" || return 1
    OK "Units generated and activated on '${ARG_DEVICE}'."
}

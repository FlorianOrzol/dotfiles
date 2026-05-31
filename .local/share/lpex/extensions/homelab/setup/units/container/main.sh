#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Generates and activates systemd units in a container.
# ==============================================================================

function extension_start {
    [[ -z "$ARG_DEVICE" ]] && { ERROR "No container specified."; return 1; }

    INFO "Generating units on container '${ARG_DEVICE}'..."
    execute_on_container "$ARG_DEVICE" "/opt/homelab/systemd/generate-units.sh" || return 1
    OK "Units generated and activated on container '${ARG_DEVICE}'."
}

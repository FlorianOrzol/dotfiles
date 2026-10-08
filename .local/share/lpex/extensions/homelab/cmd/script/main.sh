#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Runs a script of a device — validation and routing only.
# ==============================================================================

# Action file — LPEX does not auto-load _*.sh, always via $PATH_EXTENSION
source "${PATH_EXTENSION}/_script.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates device and script, then shows the help or runs it.
# ==============================================================================
function extension_start {
    local file_script

    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # Reject unknown prefixes before looking into the mirror
    cmd_validate_devices "$ARG_DEVICE" || return 1

    # Script is required — fzf already offered the device's scripts
    if [[ -z "$ARG_SCRIPT" ]]; then
        ERROR "No script specified."
        return 1
    fi

    # The mirror is the reference — an unknown path is a typo, not a missing deploy
    if ! file_script=$(cmd_script_file "$ARG_DEVICE" "$ARG_SCRIPT"); then
        ERROR "'${ARG_SCRIPT}' is not in the mirror of ${ARG_DEVICE} — see 'lpex homelab cmd script ${ARG_DEVICE} <Tab>'."
        return 1
    fi

    # --help: render the header locally, nothing is executed
    if [[ -n "$ARG_HELP" ]]; then
        _script_show_help "$file_script"
        return $?
    fi

    # Check the alias before running — a typo must not cost a second run
    if [[ -n "$ARG_SAVE" ]]; then
        cmd_validate_alias "$ARG_SAVE" || return 1
    fi

    _script_run
}

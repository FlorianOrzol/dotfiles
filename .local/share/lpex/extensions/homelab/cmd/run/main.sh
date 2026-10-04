#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Runs a command once on a device, optionally saves it.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates, runs the command and saves it on success.
# ==============================================================================
function extension_start {
    local device="$ARG_DEVICE"
    local cmd="${ARG_CMD[*]}"           # --multi delivers words — join them back
    local exit_code

    # Device is required — fzf already offered the list
    if [[ -z "$device" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # Reject unknown prefixes before asking for anything else
    cmd_validate_devices "$device" || return 1

    # Ask for the command when none was given on the command line
    if [[ -z "$cmd" ]]; then
        lx input @cmd --prompt "Command for ${device}" || return 1
    fi

    # Still empty after the prompt — nothing to run
    if [[ -z "$cmd" ]]; then
        ERROR "No command specified."
        return 1
    fi

    # Check the alias before running — a typo must not cost a second run
    if [[ -n "$ARG_SAVE" ]]; then
        cmd_validate_alias "$ARG_SAVE" || return 1
    fi

    # Route by prefix: SSH, pct exec or qm guest exec
    execute_on_target "$device" "$cmd"
    exit_code=$?

    # Save only what worked — a failing command is no shortcut
    if [[ -n "$ARG_SAVE" ]]; then
        if (( exit_code == 0 )); then
            cmd_save_alias "$ARG_SAVE" "$cmd" "${ARG_DESCRIPTION:-}" "$device"
        else
            WARN "Command failed (exit ${exit_code}) — not saved as '${ARG_SAVE}'."
        fi
    fi

    return "$exit_code"
}

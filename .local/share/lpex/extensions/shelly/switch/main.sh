#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Switches one output of a device and shows the new state.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates, switches, prints the resulting state.
# ==============================================================================
function extension_start {
    local channel="${ARG_CHANNEL:-0}"
    local summary

    # Device and action are required — fzf already offered both
    if [[ -z "$ARG_DEVICE" || -z "$ARG_ACTION" ]]; then
        ERROR "Usage: lpex shelly switch <device> <on|off|toggle>"
        return 1
    fi

    # Only the three documented actions
    if [[ ! "$ARG_ACTION" =~ ^(on|off|toggle)$ ]]; then
        ERROR "Unknown action '${ARG_ACTION}' — on, off or toggle."
        return 1
    fi

    # Brightness is a percentage
    if [[ -n "$ARG_BRIGHTNESS" ]] && ! [[ "$ARG_BRIGHTNESS" =~ ^[0-9]+$ && "$ARG_BRIGHTNESS" -ge 1 && "$ARG_BRIGHTNESS" -le 100 ]]; then
        ERROR "--brightness expects 1-100."
        return 1
    fi

    # Loads DEV_* from the inventory; protected devices need the password first
    shelly_resolve "$ARG_DEVICE" || return 1
    (( DEV_AUTH )) && { shelly_password || return 1; }

    if ! shelly_op_switch "$DEV_IP" "$DEV_GEN" "$channel" "$ARG_ACTION" "$ARG_BRIGHTNESS" >/dev/null; then
        ERROR "${DEV_ID}: switching failed."
        return 1
    fi

    # Read back instead of trusting the request — shows what really happened
    summary=$(shelly_summary "$DEV_IP" "$DEV_GEN") || { WARN "${DEV_ID}: switched, but no status answer."; return 0; }
    OK "${DEV_ID}: $(shelly_state_text "$summary") · $(jq -r '.power // 0' <<< "$summary") W"
}

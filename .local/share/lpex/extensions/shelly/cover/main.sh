#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Moves a cover (roller shutter, garage door) and reports the state.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates, sends the move command, prints the state.
# ==============================================================================
function extension_start {
    local channel="${ARG_CHANNEL:-0}"
    local summary

    # Device and action are required — fzf already offered both
    if [[ -z "$ARG_DEVICE" || -z "$ARG_ACTION" ]]; then
        ERROR "Usage: lpex shelly cover <device> <open|close|stop|0-100>"
        return 1
    fi

    # A word from the list or a percentage
    if ! [[ "$ARG_ACTION" =~ ^(open|close|stop)$ ]] && ! [[ "$ARG_ACTION" =~ ^[0-9]+$ && "$ARG_ACTION" -le 100 ]]; then
        ERROR "Unknown action '${ARG_ACTION}' — open, close, stop or 0-100."
        return 1
    fi

    # Loads DEV_* from the inventory; protected devices need the password first
    shelly_resolve "$ARG_DEVICE" || return 1
    (( DEV_AUTH )) && { shelly_password || return 1; }

    if ! shelly_op_cover "$DEV_IP" "$DEV_GEN" "$ARG_ACTION" "$channel" >/dev/null; then
        ERROR "${DEV_ID}: cover command failed (not a cover, or not calibrated for positions)."
        return 1
    fi

    # The cover keeps moving after the answer — show the state it reports now
    summary=$(shelly_summary "$DEV_IP" "$DEV_GEN") || { WARN "${DEV_ID}: sent, but no status answer."; return 0; }
    OK "${DEV_ID}: $(shelly_state_text "$summary")"
}

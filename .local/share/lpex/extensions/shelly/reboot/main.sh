#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Restarts a device and waits until it answers again.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Asks, reboots, waits for the device.
# ==============================================================================
function extension_start {
    local count_try

    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # Loads DEV_* from the inventory; protected devices need the password first
    shelly_resolve "$ARG_DEVICE" || return 1
    (( DEV_AUTH )) && { shelly_password || return 1; }

    # Outputs may switch during a restart (power-on behaviour) — ask unless --yes
    if [[ -z "$ARG_YES" ]] && ! question "Restart ${DEV_ID} (${DEV_NAME:-$DEV_IP})?" --default-no; then
        return 1
    fi

    shelly_op_reboot "$DEV_IP" "$DEV_GEN" >/dev/null || { ERROR "${DEV_ID}: reboot request failed"; return 1; }
    INFO "${DEV_ID}: restarting…"

    # Give it a moment to go down, then poll until it answers again
    sleep 5
    for count_try in {1..20}; do
        if shelly_http "$DEV_IP" "/shelly" "$DEV_GEN" >/dev/null 2>&1; then
            OK "${DEV_ID}: back online."
            return 0
        fi
        sleep 3
    done

    ERROR "${DEV_ID}: no answer after 65 s."
    return 1
}

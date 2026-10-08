#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Changes single settings of a device.
# @desc_detailed    : Every option is one step; the steps run in a fixed order —
#                     login last, because afterwards every request needs the password,
#                     and the WLAN change after it, because the device then moves.
# ==============================================================================

# Action file — LPEX does not auto-load _*.sh, always via $PATH_EXTENSION
source "${PATH_EXTENSION}/_set.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates the options and runs the requested steps.
# ==============================================================================
function extension_start {
    local flag_reboot=0

    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # At least one setting — otherwise the call is a forgotten option
    if [[ -z "$ARG_NAME$ARG_CLOUD$ARG_MQTT$ARG_AUTH$ARG_DEFAULT_STATE$ARG_WIFI" ]]; then
        ERROR "Nothing to set — see 'lpex shelly config set --<Tab>'."
        return 1
    fi

    _set_validate || return 1

    # Loads DEV_* from the inventory; protected devices need the password first
    shelly_resolve "$ARG_DEVICE" || return 1
    (( DEV_AUTH )) && { shelly_password || return 1; }

    # Fixed order: plain settings, MQTT, login, WLAN last
    [[ -n "$ARG_NAME" ]]          && { _set_name || return 1; }
    [[ -n "$ARG_CLOUD" ]]         && { _set_cloud || return 1; }
    [[ -n "$ARG_DEFAULT_STATE" ]] && { _set_default_state || return 1; }
    [[ -n "$ARG_MQTT" ]]          && { _set_mqtt || return 1; (( DEV_GEN == 1 )) && flag_reboot=1; }
    [[ -n "$ARG_AUTH" ]]          && { _set_auth || return 1; }

    # Gen1 activates MQTT changes only after a restart
    if (( flag_reboot )) && [[ -z "$ARG_WIFI" ]]; then
        shelly_op_reboot "$DEV_IP" "$DEV_GEN" >/dev/null && INFO "${DEV_ID}: rebooting to activate MQTT (~15 s)"
    fi

    [[ -n "$ARG_WIFI" ]] && { _set_wifi || return 1; }
    return 0
}

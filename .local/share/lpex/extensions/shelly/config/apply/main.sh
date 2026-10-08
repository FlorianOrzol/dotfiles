#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Applies a settings profile (cloud, MQTT, login) to one device.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Shows what will change, asks, applies the profile.
# ==============================================================================
function extension_start {
    local profile only="${ARG_ONLY:-cloud,mqtt,auth}" part

    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # Only the three known parts
    for part in ${only//,/ }; do
        if [[ ! "$part" =~ ^(cloud|mqtt|auth)$ ]]; then
            ERROR "Unknown part '${part}' — cloud, mqtt, auth."
            return 1
        fi
    done

    # Loads DEV_* from the inventory; protected devices need the password first
    shelly_resolve "$ARG_DEVICE" || return 1
    (( DEV_AUTH )) && { shelly_password || return 1; }
    profile="${ARG_PROFILE:-${DEV_PROFILE:-default}}"

    # Show the plan before touching the device
    INFO "${DEV_ID} (${DEV_IP}) ← profile '${profile}', parts: ${only}"
    [[ ",$only," == *,cloud,* ]] && INFO "  cloud $( (( $(shelly_profile_value "$profile" CLOUD) )) && echo on || echo off)"
    [[ ",$only," == *,mqtt,*  ]] && INFO "  mqtt  $( (( $(shelly_profile_value "$profile" MQTT) )) && echo "on → ${SHELLY_MQTT_SERVER}, login ${DEV_ID}" || echo off)"
    [[ ",$only," == *,auth,*  ]] && INFO "  login $( (( $(shelly_profile_value "$profile" AUTH) )) && echo "on (${SHELLY_AUTH_USER})" || echo off)"

    # Login on breaks every tool that talks to the device without the password
    if [[ ",$only," == *,auth,* ]] && (( $(shelly_profile_value "$profile" AUTH) && ! DEV_AUTH )); then
        WARN "Login on: the old Node-RED (CT 11010) and other tools without the password lose access to ${DEV_ID}."
    fi

    # Changing a live device is asked unless --yes
    if [[ -z "$ARG_YES" ]] && ! question "Apply to ${DEV_ID}?" --default-no; then
        INFO "Nothing changed."
        return 1
    fi

    shelly_apply_profile "$DEV_ID" "$DEV_IP" "$DEV_GEN" "$profile" "$only"
}

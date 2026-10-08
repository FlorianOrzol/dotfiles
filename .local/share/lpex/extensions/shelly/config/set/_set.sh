#!/bin/bash
# ==============================================================================
# @meta_name        : _set.sh
# @desc_short       : Single steps of 'shelly config set' — one function per option.
# @notes            : DEV_* are loaded by main.sh (shelly_resolve).
# ==============================================================================

# --- _set_validate ---
# @desc_short  : Checks option values before anything is sent.
# ==============================================================================
function _set_validate {
    local option value

    # on/off options
    for option in CLOUD MQTT AUTH; do
        local name_var="ARG_${option}"
        value="${!name_var}"
        if [[ -n "$value" && ! "$value" =~ ^(on|off)$ ]]; then
            ERROR "--${option,,} expects on or off."
            return 1
        fi
    done

    # Power-on behaviour
    if [[ -n "$ARG_DEFAULT_STATE" && ! "$ARG_DEFAULT_STATE" =~ ^(on|off|last|switch)$ ]]; then
        ERROR "--default-state expects on, off, last or switch."
        return 1
    fi

    # WLAN: static needs an address in dotted form
    if [[ -n "$ARG_WIFI" ]]; then
        if [[ ! "$ARG_WIFI" =~ ^(static|dhcp)$ ]]; then
            ERROR "--wifi expects static or dhcp."
            return 1
        fi
        if [[ "$ARG_WIFI" == "static" && ! "$ARG_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            ERROR "--wifi static needs --ip <address>."
            return 1
        fi
    fi
}

# --- _set_name ---
# @desc_short  : Writes the name to the device and to the inventory.
# ==============================================================================
function _set_name {
    # Device first — the inventory follows only what the device accepted
    shelly_op_name "$DEV_IP" "$DEV_GEN" "$ARG_NAME" >/dev/null || { ERROR "${DEV_ID}: name not accepted"; return 1; }
    lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "mac='${DEV_MAC}'" --data "name" "$ARG_NAME"
    OK "${DEV_ID}: name '${ARG_NAME}' (id stays — change it with 'lpex shelly edit --id')"
}

# --- _set_cloud ---
# @desc_short  : Shelly cloud on/off.
# ==============================================================================
function _set_cloud {
    local enable=0
    [[ "$ARG_CLOUD" == "on" ]] && enable=1

    # Gen1 cannot keep MQTT when the cloud comes on
    if (( enable && DEV_GEN == 1 )); then
        WARN "${DEV_ID}: Gen1 — cloud and MQTT exclude each other."
    fi

    shelly_op_cloud "$DEV_IP" "$DEV_GEN" "$enable" >/dev/null || { ERROR "${DEV_ID}: cloud setting failed"; return 1; }
    OK "${DEV_ID}: cloud ${ARG_CLOUD}"
}

# --- _set_default_state ---
# @desc_short  : Power-on behaviour of one output.
# ==============================================================================
function _set_default_state {
    local channel="${ARG_CHANNEL:-0}"

    shelly_op_default_state "$DEV_IP" "$DEV_GEN" "$channel" "$ARG_DEFAULT_STATE" >/dev/null \
        || { ERROR "${DEV_ID}: power-on behaviour not accepted (output ${channel})"; return 1; }
    OK "${DEV_ID}: output ${channel} power-on behaviour '${ARG_DEFAULT_STATE}'"
}

# --- _set_mqtt ---
# @desc_short  : MQTT via the profile helper — broker account included.
# ==============================================================================
function _set_mqtt {
    local profile_tmp="_set_${RANDOM}"

    # Reuse the profile logic for exactly one part, with the wanted value
    declare -g "SHELLY_PROFILE_${profile_tmp^^}_MQTT=$( [[ "$ARG_MQTT" == "on" ]] && echo 1 || echo 0)"
    _set_apply_part "$profile_tmp" "mqtt"
}

# --- _set_auth ---
# @desc_short  : Device login on/off via the profile helper.
# ==============================================================================
function _set_auth {
    local profile_tmp="_set_${RANDOM}"

    # A protected device stops answering the old Node-RED (CT 11010) — say so
    [[ "$ARG_AUTH" == "on" ]] && WARN "${DEV_ID}: with login on, tools without the password (old Node-RED on CT 11010) lose access."

    declare -g "SHELLY_PROFILE_${profile_tmp^^}_AUTH=$( [[ "$ARG_AUTH" == "on" ]] && echo 1 || echo 0)"
    _set_apply_part "$profile_tmp" "auth"
}

# --- _set_apply_part ---
# @desc_short  : Runs shelly_apply_profile for one part without changing the stored profile.
# @usage       : _set_apply_part <temporary-profile> <part>
# ==============================================================================
function _set_apply_part {
    local profile_tmp="$1" part="$2"

    # No pipe: apply exports the device password for the following steps.
    # No reboot here — main.sh reboots once after all steps.
    shelly_apply_profile "$DEV_ID" "$DEV_IP" "$DEV_GEN" "$profile_tmp" "$part" 1 || return 1

    # apply writes the profile name — put the device's own profile back
    lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "mac='${DEV_MAC}'" --data "profile" "${DEV_PROFILE:-default}"
}

# --- _set_wifi ---
# @desc_short  : Re-addresses the device (static/DHCP) and follows it to the new address.
# @notes       : SSID and password from the config — the device rejoins the same WLAN.
# ==============================================================================
function _set_wifi {
    local password ip_new="${ARG_IP:-}" count_try

    password=$(shelly_secret wifi) || return 1

    WARN "${DEV_ID}: leaving ${DEV_IP} — reconnects to '${SHELLY_WIFI_SSID}' as ${ARG_WIFI}${ip_new:+ ${ip_new}}."
    shelly_op_wifi "$DEV_IP" "$DEV_GEN" "$SHELLY_WIFI_SSID" "$password" "$ARG_WIFI" \
        "$ip_new" "$SHELLY_NET_MASK" "$SHELLY_NET_GATEWAY" "$SHELLY_NET_DNS" >/dev/null \
        || { ERROR "${DEV_ID}: WLAN setting failed"; return 1; }

    # DHCP: the new address is unknown — the next scan finds the device by MAC
    if [[ "$ARG_WIFI" == "dhcp" ]]; then
        INFO "${DEV_ID}: DHCP — run 'lpex shelly scan' in a minute to pick up the new address."
        return 0
    fi

    # Static: wait until the device answers at its new address
    for count_try in {1..30}; do
        if shelly_http "$ip_new" "/shelly" "$DEV_GEN" >/dev/null 2>&1; then
            lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "mac='${DEV_MAC}'" \
                --data "ip" "$ip_new" "ip_mode" "static"
            OK "${DEV_ID}: now at ${ip_new}"
            return 0
        fi
        sleep 2
    done

    ERROR "${DEV_ID}: no answer at ${ip_new} after 60 s — check with 'lpex shelly scan'."
    return 1
}

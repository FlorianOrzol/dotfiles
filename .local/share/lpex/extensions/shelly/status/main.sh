#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Details of one device — live, or the last known state when offline.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Loads the device, fetches its status and prints the details.
# ==============================================================================
function extension_start {
    local summary flag_online=1 cached_at

    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # Loads DEV_* from the inventory
    shelly_resolve "$ARG_DEVICE" || return 1

    # Protected device: fetch the password before the first request
    if (( DEV_AUTH )); then
        shelly_password || return 1
    fi

    # --raw: the untouched API answers, for everything the summary leaves out
    if [[ -n "$ARG_RAW" ]]; then
        _status_raw
        return $?
    fi

    # Live first; an unreachable device falls back to the cached status
    if ! summary=$(shelly_summary "$DEV_IP" "$DEV_GEN"); then
        flag_online=0
        IFS=$'\x1f' read -r summary cached_at <<< "$(shelly_sql "SELECT last_status, last_status_at FROM ${TABLE_SHELLY} WHERE id='${DEV_ID}';")"
    else
        lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "id='${DEV_ID}'" \
            --data "last_status" "$summary" "last_status_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "last_seen_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    fi

    _status_print "$summary" "$flag_online" "$cached_at"
}

# --- _status_raw ---
# @desc_short  : Prints status and configuration exactly as the device answers.
# ==============================================================================
function _status_raw {
    local path_status="/status" path_config="/settings"

    # Gen2+ speak RPC
    if (( DEV_GEN >= 2 )); then
        path_status="/rpc/Shelly.GetStatus"
        path_config="/rpc/Shelly.GetConfig"
    fi

    # Both answers in one object — pipe into jq for anything specific
    jq -n --argjson s "$(shelly_http "$DEV_IP" "$path_status" "$DEV_GEN" || echo null)" \
          --argjson c "$(shelly_http "$DEV_IP" "$path_config" "$DEV_GEN" || echo null)" \
          '{status: $s, config: $c}'
}

# --- _status_print ---
# @desc_short  : Prints inventory facts and the summary as an aligned block.
# @usage       : _status_print <summary-json> <flag_online> [cached_at]
# ==============================================================================
function _status_print {
    local summary="${1:-{\}}" flag_online="$2" cached_at="$3"
    local line_online

    # Offline: say clearly that the values are old and how old
    if (( flag_online )); then
        line_online="online"
    else
        line_online="OFFLINE — values from ${cached_at:-never}"
    fi

    lx output --section "${DEV_NAME:-$DEV_ID}"

    printf '  %-12s %s\n' \
        "id"       "$DEV_ID" \
        "room"     "${DEV_ROOM:--}" \
        "model"    "$(shelly_model_text "$DEV_MODEL") (${DEV_MODEL}, Gen${DEV_GEN})" \
        "mac"      "$DEV_MAC" \
        "network"  "${DEV_IP} · ${DEV_IP_MODE:-?} · WLAN ${DEV_SSID:-?} · RSSI $(jq -r '.rssi // "?"' <<< "$summary")" \
        "state"    "$line_online" \
        "outputs"  "$(shelly_state_text "$summary")" \
        "power"    "$(jq -r '(.power // 0 | . * 10 | round / 10 | tostring) + " W · total " + (.energy_wh // 0 | . / 1000 | . * 100 | round / 100 | tostring) + " kWh"' <<< "$summary")" \
        "temp"     "$(jq -r '.temp // "-" | tostring' <<< "$summary")" \
        "mqtt"     "$(jq -r 'if .mqtt then "connected" else "off/disconnected" end' <<< "$summary")" \
        "cloud"    "$(jq -r 'if .cloud then "connected" else "off/disconnected" end' <<< "$summary")" \
        "login"    "$( (( DEV_AUTH )) && echo "on" || echo "OFF — device unprotected")" \
        "firmware" "${DEV_FW}" \
        "update"   "$(jq -r '.update // "none"' <<< "$summary")" \
        "uptime"   "$(jq -r '.uptime // 0 | (. / 86400 | floor | tostring) + "d"' <<< "$summary")" \
        "profile"  "${DEV_PROFILE:-default}" \
        "notes"    "${DEV_NOTES:--}"
}

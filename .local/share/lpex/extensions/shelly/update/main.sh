#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Checks for and installs firmware updates.
# @desc_detailed    : One device: check, ask, install, wait for the device to return
#                     and record the new firmware. 'all': check every device and
#                     install on those with an update, one after the other.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Builds the target list and runs check/install per device.
# ==============================================================================
function extension_start {
    local -a targets=()
    local id count_updates=0

    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # 'all' = every inventory device; otherwise exactly the given one
    if [[ "$ARG_DEVICE" == "all" ]]; then
        mapfile -t targets < <(shelly_sql "SELECT id FROM ${TABLE_SHELLY} ORDER BY id;")
    else
        shelly_resolve "$ARG_DEVICE" || return 1
        targets=("$DEV_ID")
    fi

    # One device after the other — a mass reboot would take the whole house offline at once
    for id in "${targets[@]}"; do
        _update_one "$id" && (( count_updates++ ))
    done

    echo
    INFO "${count_updates} of ${#targets[@]} device(s) $( [[ -n "$ARG_CHECK" ]] && echo "have an update" || echo "updated")."
}

# --- _update_one ---
# @desc_short  : Checks one device; installs when allowed. Returns 0 when an update exists/ran.
# @usage       : _update_one <id>
# ==============================================================================
function _update_one {
    local id="$1"
    local versions fw_old fw_new count_try fw_now

    shelly_resolve "$id" >/dev/null || return 1
    (( DEV_AUTH )) && { shelly_password || return 1; }

    # Offline devices cannot be checked — skip them, do not abort the run
    if ! versions=$(shelly_op_update_check "$DEV_IP" "$DEV_GEN" 2>/dev/null); then
        WARN "${DEV_ID}: offline — skipped."
        return 1
    fi
    read -r fw_old fw_new <<< "$versions"

    # Up to date: nothing to do
    if [[ "$fw_new" == "none" || -z "$fw_new" ]]; then
        INFO "${DEV_ID}: up to date (${fw_old})"
        return 1
    fi

    INFO "${DEV_ID}: ${fw_old} → ${fw_new}"

    # --check stops after reporting
    [[ -n "$ARG_CHECK" ]] && return 0

    # Installing means ~1 minute without function — ask unless --yes
    if [[ -z "$ARG_YES" ]] && ! question "Install on ${DEV_ID} (device restarts)?" --default-no; then
        return 1
    fi

    shelly_op_update_run "$DEV_IP" "$DEV_GEN" >/dev/null || { ERROR "${DEV_ID}: update start failed"; return 1; }
    INFO "${DEV_ID}: installing — waiting for the device to come back (max. 3 min)…"

    # The device downloads, flashes and reboots; poll until the version changed
    sleep 20
    for count_try in {1..32}; do
        fw_now=$(shelly_identity "$DEV_IP" 2>/dev/null | jq -r '.fw // empty')
        if [[ -n "$fw_now" && "$fw_now" != "$fw_old" ]]; then
            lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "mac='${DEV_MAC}'" \
                --data "fw" "$fw_now" "last_seen_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            OK "${DEV_ID}: now ${fw_now}"
            return 0
        fi
        sleep 5
    done

    ERROR "${DEV_ID}: firmware unchanged after 3 minutes — check with 'lpex shelly status ${DEV_ID}'."
    return 1
}

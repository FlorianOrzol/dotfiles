#!/bin/bash
# ==============================================================================
# @meta_name        : _setup.sh
# @desc_short       : Steps of 'shelly setup' — wlan0, access point, configure, LAN.
# @desc_detailed    : Shared state lives in SETUP_* globals. iwctl works without root
# @desc_detailed    : for members of 'wheel' (iwd D-Bus policy) and D-Bus activates iwd;
# @desc_detailed    : only stopping the iwd service needs sudo. systemd-networkd gives
# @desc_detailed    : wlan0 its address (20-wlan.network, DHCP, route metric 600 — the
# @desc_detailed    : LAN stays preferred).
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
DEVICE_SETUP_WLAN="wlan0"            # interface that joins the Shelly access point
TIMEOUT_SETUP_AP=60                  # seconds to wait for an address on the AP
TIMEOUT_SETUP_LAN=120                # seconds to wait for the device in the LAN

# --- _setup_access_point_part ---
# @desc_short  : Every step that needs wlan0 on the access point, in order.
# ==============================================================================
function _setup_access_point_part {
    _setup_wifi_up        || return 1
    _setup_choose_ap      || return 1
    _setup_connect_ap     || return 1
    _setup_identify       || return 1
    _setup_collect_values || return 1
    _setup_configure      || return 1
    _setup_join_wifi
}

# --- _setup_validate ---
# @desc_short  : Checks options and the config before touching the network.
# ==============================================================================
function _setup_validate {
    # Static and DHCP at once is a contradiction
    if [[ -n "$ARG_IP" && -n "$ARG_DHCP" ]]; then
        ERROR "--ip and --dhcp exclude each other."
        return 1
    fi

    # A given address must look like one
    if [[ -n "$ARG_IP" && ! "$ARG_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        ERROR "--ip '${ARG_IP}' is no IPv4 address."
        return 1
    fi

    # A given id must be a valid slug
    if [[ -n "$ARG_ID" && ! "$ARG_ID" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
        ERROR "Invalid id '${ARG_ID}' — lowercase a-z, 0-9 and single '-'."
        return 1
    fi

    # Without a WLAN name the device has nowhere to go
    SETUP_SSID="${ARG_SSID:-$SHELLY_WIFI_SSID}"
    if [[ -z "$SETUP_SSID" ]]; then
        ERROR "No WLAN — set SHELLY_WIFI_SSID (lpex --config shelly) or pass --ssid."
        return 1
    fi

    # The WLAN interface must exist on this machine
    if [[ ! -e "/sys/class/net/${DEVICE_SETUP_WLAN}" ]]; then
        ERROR "No ${DEVICE_SETUP_WLAN} on this machine."
        return 1
    fi

    # Fetch the WLAN password now — a failing rbw must not stop us mid-setup
    SETUP_WIFI_PASSWORD=$(shelly_secret wifi) || return 1
}

# --- _setup_wifi_up ---
# @desc_short  : Makes sure iwd runs; remembers whether we started it.
# @notes       : iwd is D-Bus activated — the first iwctl call starts it for members
#                of 'wheel', no sudo needed. Only stopping it again needs root.
#                With -s (show only) the setup stops here, before wlan0 is touched.
# ==============================================================================
function _setup_wifi_up {
    local count_try

    SETUP_IWD_STARTED=0

    # -s: show the plan, change nothing — not even the D-Bus activation of iwd
    if (( ${ARG_ONLY_SHOW:-0} )); then
        INFO "Dry run (-s): would start iwd, scan for 'shelly*' networks, join one and configure the device."
        return 1
    fi

    # iwd already running — leave it as we found it
    systemctl is-active --quiet iwd && return 0

    INFO "Starting iwd for ${DEVICE_SETUP_WLAN} (D-Bus activation, stopped again at the end)…"
    SETUP_IWD_STARTED=1
    iwctl device list >/dev/null 2>&1

    # iwd needs a moment to create the station on the interface
    for count_try in {1..10}; do
        iwctl station "$DEVICE_SETUP_WLAN" show >/dev/null 2>&1 && return 0
        sleep 1
    done

    ERROR "iwd started, but no station on ${DEVICE_SETUP_WLAN}."
    return 1
}

# --- _setup_choose_ap ---
# @desc_short  : Scans for 'shelly*' access points and lets the user pick one.
# ==============================================================================
function _setup_choose_ap {
    local list choice

    # --ap skips the scan
    if [[ -n "$ARG_AP" ]]; then
        SETUP_AP="$ARG_AP"
        return 0
    fi

    INFO "Scanning for Shelly access points…"
    iwctl station "$DEVICE_SETUP_WLAN" scan 2>/dev/null
    sleep 4

    # get-networks prints a coloured table — strip colours, keep lines naming a Shelly
    list=$(iwctl station "$DEVICE_SETUP_WLAN" get-networks 2>/dev/null \
             | sed -E 's/\x1b\[[0-9;]*m//g; s/^[ >]*//' \
             | grep -i -E '^shelly' | awk '{print $1}' | sort -u)

    # A Shelly in setup mode offers an open network named shelly…/Shelly…
    if [[ -z "$list" ]]; then
        ERROR "No Shelly access point found. Put the device into setup mode (reset: hold the button ~10 s)."
        return 1
    fi

    # One network: take it; several: let the user choose
    if [[ $(wc -l <<< "$list") -eq 1 ]]; then
        SETUP_AP="$list"
    else
        lx fzf @choice --list "$list" --header "Which Shelly?" --prompt "AP > " --no-input
        SETUP_AP="${choice%% *}"
    fi

    [[ -n "$SETUP_AP" ]] || return 1
    INFO "Access point: ${SETUP_AP}"
}

# --- _setup_connect_ap ---
# @desc_short  : Joins the access point and waits until the device answers.
# ==============================================================================
function _setup_connect_ap {
    local count_try

    # Shelly access points are open — no passphrase prompt
    if ! iwctl station "$DEVICE_SETUP_WLAN" connect "$SETUP_AP" 2>/dev/null; then
        ERROR "Could not join '${SETUP_AP}'."
        return 1
    fi

    # networkd hands out the address; the device answers at 192.168.33.1
    for (( count_try = 0; count_try < TIMEOUT_SETUP_AP / 2; count_try++ )); do
        if curl -s -m 2 --interface "$DEVICE_SETUP_WLAN" "http://${IP_SHELLY_AP}/shelly" >/dev/null 2>&1; then
            OK "Connected to ${SETUP_AP} — device answers at ${IP_SHELLY_AP}"
            return 0
        fi
        sleep 2
    done

    ERROR "Joined '${SETUP_AP}', but ${IP_SHELLY_AP} does not answer."
    return 1
}

# --- _setup_identify ---
# @desc_short  : Reads model, generation and MAC of the device in setup mode.
# ==============================================================================
function _setup_identify {
    local id_known

    SETUP_IDENTITY=$(shelly_identity "$IP_SHELLY_AP") || { ERROR "No answer from ${IP_SHELLY_AP}/shelly"; return 1; }
    SETUP_GEN=$(jq -r .gen <<< "$SETUP_IDENTITY")
    SETUP_MAC=$(jq -r .mac <<< "$SETUP_IDENTITY")
    SETUP_MODEL=$(jq -r .model <<< "$SETUP_IDENTITY")

    INFO "Found $(shelly_model_text "$SETUP_MODEL") (Gen${SETUP_GEN}), MAC ${SETUP_MAC}, firmware $(jq -r .fw <<< "$SETUP_IDENTITY")"

    # A reset device that is already in the inventory keeps its id and room
    id_known=$(shelly_sql "SELECT id FROM ${TABLE_SHELLY} WHERE mac='${SETUP_MAC}';")
    if [[ -n "$id_known" ]]; then
        SETUP_ID_KNOWN="$id_known"
        INFO "Known as '${id_known}' — its inventory row is updated."
    fi
}

# --- _setup_collect_values ---
# @desc_short  : Name, id, room and address — from options, otherwise asked.
# ==============================================================================
function _setup_collect_values {
    local suggestion

    # Name: option, otherwise the known one, otherwise asked
    SETUP_NAME="$ARG_NAME"
    if [[ -z "$SETUP_NAME" && -n "${SETUP_ID_KNOWN:-}" ]]; then
        SETUP_NAME=$(shelly_sql "SELECT name FROM ${TABLE_SHELLY} WHERE id='${SETUP_ID_KNOWN}';")
    fi
    if [[ -z "$SETUP_NAME" ]]; then
        lx input @SETUP_NAME --prompt "Device name (e.g. Stehlampe Wohnzimmer)" || return 1
    fi
    [[ -n "$SETUP_NAME" ]] || { ERROR "A name is required."; return 1; }

    # Id: option, known one, or the slug of the name made unique
    SETUP_ID="${ARG_ID:-${SETUP_ID_KNOWN:-$(shelly_unique_id "$(shelly_slug "$SETUP_NAME")" "$SETUP_MAC")}}"
    SETUP_ROOM="$ARG_ROOM"
    SETUP_PROFILE="${ARG_PROFILE:-default}"

    # Address: DHCP, the given one, or the first free one from the pool (confirmed)
    if [[ -n "$ARG_DHCP" || "$SHELLY_NET_MODE" == "dhcp" && -z "$ARG_IP" ]]; then
        SETUP_MODE="dhcp"
        SETUP_IP=""
    else
        SETUP_MODE="static"
        SETUP_IP="$ARG_IP"
        if [[ -z "$SETUP_IP" ]]; then
            suggestion=$(shelly_next_free_ip "${SHELLY_IP_POOL:-10.0.11.0/24}")
            if question "Use ${suggestion:-?} (first free address in ${SHELLY_IP_POOL})?" && [[ -n "$suggestion" ]]; then
                SETUP_IP="$suggestion"
            else
                lx input @SETUP_IP --prompt "Static address" || return 1
            fi
        fi
    fi

    INFO "→ ${SETUP_ID} · '${SETUP_NAME}' · ${SETUP_MODE}${SETUP_IP:+ ${SETUP_IP}} · WLAN ${SETUP_SSID} · profile ${SETUP_PROFILE}"
}

# --- _setup_configure ---
# @desc_short  : Writes inventory row, name and profile while the device is on its AP.
# ==============================================================================
function _setup_configure {
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Row first: shelly_apply_profile records auth/profile in it
    if [[ -n "${SETUP_ID_KNOWN:-}" ]]; then
        lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "mac='${SETUP_MAC}'" \
            --data "id" "$SETUP_ID" "name" "$SETUP_NAME" "gen" "$SETUP_GEN" "model" "$SETUP_MODEL" \
                   "ip" "$SETUP_IP" "ip_mode" "$SETUP_MODE" "ssid" "$SETUP_SSID"
    else
        lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --insert \
            --data "id" "$SETUP_ID" "mac" "$SETUP_MAC" "name" "$SETUP_NAME" "gen" "$SETUP_GEN" \
                   "model" "$SETUP_MODEL" "ip" "$SETUP_IP" "ip_mode" "$SETUP_MODE" "ssid" "$SETUP_SSID" \
                   "fw" "$(jq -r .fw <<< "$SETUP_IDENTITY")" "auth" "0" "added_at" "$now"
    fi
    [[ -n "$SETUP_ROOM" ]] && lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "mac='${SETUP_MAC}'" --data "room" "$SETUP_ROOM"

    # Name, then the profile — no reboot now, the WLAN change restarts the device anyway
    shelly_op_name "$IP_SHELLY_AP" "$SETUP_GEN" "$SETUP_NAME" >/dev/null || { ERROR "Name not accepted"; return 1; }
    OK "${SETUP_ID}: name '${SETUP_NAME}'"
    shelly_apply_profile "$SETUP_ID" "$IP_SHELLY_AP" "$SETUP_GEN" "$SETUP_PROFILE" "cloud,mqtt,auth" 1 || return 1
}

# --- _setup_join_wifi ---
# @desc_short  : Sends the home WLAN — last step on the access point.
# ==============================================================================
function _setup_join_wifi {
    # After this answer the device leaves 192.168.33.1
    shelly_op_wifi "$IP_SHELLY_AP" "$SETUP_GEN" "$SETUP_SSID" "$SETUP_WIFI_PASSWORD" "$SETUP_MODE" \
        "$SETUP_IP" "$SHELLY_NET_MASK" "$SHELLY_NET_GATEWAY" "$SHELLY_NET_DNS" >/dev/null \
        || { ERROR "WLAN setting not accepted"; return 1; }
    OK "${SETUP_ID}: joins '${SETUP_SSID}' (${SETUP_MODE}${SETUP_IP:+ ${SETUP_IP}})"

    # Gen2+ need a restart to switch from AP to the home WLAN
    (( SETUP_GEN >= 2 )) && shelly_op_reboot "$IP_SHELLY_AP" "$SETUP_GEN" >/dev/null
    return 0
}

# --- _setup_wifi_down ---
# @desc_short  : Leaves and forgets the access point; stops iwd if this setup started it.
# ==============================================================================
function _setup_wifi_down {
    # Nothing to undo when wlan0 was never touched (validation error, -s)
    (( ${ARG_ONLY_SHOW:-0} )) && return 0
    systemctl is-active --quiet iwd || return 0

    # Disconnect is harmless when not connected
    iwctl station "$DEVICE_SETUP_WLAN" disconnect >/dev/null 2>&1

    # iwd remembers every joined network — a reset Shelly would be joined again on its own
    if [[ -n "${SETUP_AP:-}" ]]; then
        iwctl known-networks "$SETUP_AP" forget >/dev/null 2>&1
    fi

    # Restore the state we found: iwd off when we switched it on (needs root)
    if (( ${SETUP_IWD_STARTED:-0} )); then
        SETUP_IWD_STARTED=0
        lx cmd --run "sudo systemctl stop iwd" \
            --title "Stop iwd again (it was not running before the setup)" \
            --confirm || WARN "iwd keeps running — harmless, stop it later: sudo systemctl stop iwd"
    fi
}

# --- _setup_await_lan ---
# @desc_short  : Waits for the device in the LAN — at its static address or found by MAC.
# ==============================================================================
function _setup_await_lan {
    local count_try ip_found

    INFO "Waiting for ${SETUP_ID} in the LAN (max. ${TIMEOUT_SETUP_LAN} s)…"

    for (( count_try = 0; count_try < TIMEOUT_SETUP_LAN / 10; count_try++ )); do
        sleep 10

        # Static: ask the known address
        if [[ "$SETUP_MODE" == "static" ]]; then
            shelly_http "$SETUP_IP" "/shelly" "$SETUP_GEN" >/dev/null 2>&1 && { SETUP_IP_LAN="$SETUP_IP"; break; }
            continue
        fi

        # DHCP: probe the scan ranges for the MAC
        ip_found=$(shelly_expand_ranges "$SHELLY_SCAN_RANGES" \
                     | xargs -r -P "$COUNT_SHELLY_PARALLEL" -n 1 bash -c '_shelly_probe_worker "$@"' _ \
                     | awk -F$'\x1f' -v mac="$SETUP_MAC" 'index($2, "\"" mac "\"") {print $1; exit}')
        [[ -n "$ip_found" ]] && { SETUP_IP_LAN="$ip_found"; break; }
    done

    # Not found: the inventory row stays, the next scan picks the device up
    if [[ -z "${SETUP_IP_LAN:-}" ]]; then
        ERROR "${SETUP_ID} did not show up in the LAN — check the WLAN password, then 'lpex shelly scan'."
        return 1
    fi

    OK "${SETUP_ID} is online at ${SETUP_IP_LAN}"
}

# --- _setup_finish ---
# @desc_short  : Records the LAN address, activates Gen1 MQTT and shows the result.
# ==============================================================================
function _setup_finish {
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "mac='${SETUP_MAC}'" \
        --data "ip" "$SETUP_IP_LAN" "last_seen_at" "$now"

    # Gen1 activates MQTT only after a restart — now that it is in the LAN
    if (( SETUP_GEN == 1 && $(shelly_profile_value "$SETUP_PROFILE" MQTT) )); then
        shelly_op_reboot "$SETUP_IP_LAN" 1 >/dev/null && INFO "${SETUP_ID}: rebooting to activate MQTT (~15 s)"
        sleep 15
    fi

    echo
    OK "Setup of ${SETUP_ID} complete — details: lpex shelly status ${SETUP_ID}"
}

#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Finds Shellys in the LAN and syncs them with the inventory.
# @desc_detailed    : Known devices (matched by MAC) get IP, firmware, model and
#                     last_seen updated — an IP change is reported. New devices
#                     are listed, and added with --add. Known devices that did not
#                     answer are listed as missing.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Probes the ranges in parallel and reconciles the results.
# ==============================================================================
function extension_start {
    local ranges="${ARG_RANGE[*]:-$SHELLY_SCAN_RANGES}"
    local ip identity mac id_known ip_known id_new now
    local count_new=0 count_known=0 count_added=0
    local -a macs_found

    shelly_db_init
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    lx output --section "Scanning ${ranges}"

    # Probe every host in parallel; only Shellys print a line
    while IFS=$'\x1f' read -r ip identity; do
        mac=$(jq -r .mac <<< "$identity")
        macs_found+=("$mac")

        # Known device: same MAC already in the inventory
        IFS=$'\x1f' read -r id_known ip_known <<< "$(shelly_sql "SELECT id, ip FROM ${TABLE_SHELLY} WHERE mac='${mac}';")"
        if [[ -n "$id_known" ]]; then
            (( count_known++ ))
            _scan_update_known "$id_known" "$ip" "$identity" "$now"

            # A moved device is worth a line — DHCP or a re-flash changed its address
            if [[ "$ip_known" != "$ip" ]]; then
                WARN "${id_known}: IP changed ${ip_known} → ${ip}"
            fi
            continue
        fi

        (( count_new++ ))

        # New device: add with --add, otherwise only report
        if [[ -n "$ARG_ADD" ]]; then
            id_new=$(_scan_add_new "$ip" "$identity" "$now")
            OK "added ${id_new} — $(jq -r '.name // "(no name)"' <<< "$identity") · $(shelly_model_text "$(jq -r .model <<< "$identity")") · ${ip}"
            (( count_added++ ))
        else
            INFO "new: ${ip} — $(jq -r '.name // "(no name)"' <<< "$identity") · $(shelly_model_text "$(jq -r .model <<< "$identity")") · Gen$(jq -r .gen <<< "$identity") · ${mac}"
        fi
    done < <(shelly_expand_ranges "$ranges" | xargs -r -P "$COUNT_SHELLY_PARALLEL" -n 1 bash -c '_shelly_probe_worker "$@"' _)

    # Missing devices only make sense when the whole configured LAN was probed
    if [[ -z "${ARG_RANGE[*]}" ]]; then
        _scan_report_missing "${macs_found[@]}"
    fi

    echo
    INFO "${count_known} known, ${count_new} new$( [[ -n "$ARG_ADD" ]] && echo ", ${count_added} added")."

    # Point the user to --add when there is something to add
    if (( count_new > 0 )) && [[ -z "$ARG_ADD" ]]; then
        INFO "Add them with: lpex shelly scan --add"
    fi
}

# --- _scan_update_known ---
# @desc_short  : Refreshes the device facts of a known row.
# @usage       : _scan_update_known <id> <ip> <identity-json> <timestamp>
# ==============================================================================
function _scan_update_known {
    local id="$1" ip="$2" identity="$3" now="$4"

    # Device facts follow the device; name/room/profile stay as edited in the inventory
    lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "id='${id}'" \
        --data "ip" "$ip" \
               "gen" "$(jq -r .gen <<< "$identity")" \
               "model" "$(jq -r .model <<< "$identity")" \
               "fw" "$(jq -r .fw <<< "$identity")" \
               "auth" "$(jq -r .auth <<< "$identity")" \
               "ip_mode" "$(jq -r '.ip_mode // ""' <<< "$identity")" \
               "ssid" "$(jq -r '.ssid // ""' <<< "$identity")" \
               "last_seen_at" "$now"
}

# --- _scan_add_new ---
# @desc_short  : Inserts a new device and prints its id.
# @usage       : id=$(_scan_add_new <ip> <identity-json> <timestamp>)
# @notes       : id = slug of the device name; without a name model + last 6 MAC chars.
# ==============================================================================
function _scan_add_new {
    local ip="$1" identity="$2" now="$3"
    local name mac model id_wanted id

    name=$(jq -r '.name // ""' <<< "$identity")
    mac=$(jq -r .mac <<< "$identity")
    model=$(jq -r .model <<< "$identity")

    # Named devices keep their name as id; unnamed ones get model + MAC tail
    if [[ -n "$name" ]]; then
        id_wanted=$(shelly_slug "$name")
    else
        id_wanted=$(shelly_slug "$(shelly_model_text "$model")-${mac: -6}")
    fi
    id=$(shelly_unique_id "$id_wanted" "$mac")

    lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --insert \
        --data "id" "$id" "mac" "$mac" "name" "$name" \
               "gen" "$(jq -r .gen <<< "$identity")" "model" "$model" "ip" "$ip" \
               "ip_mode" "$(jq -r '.ip_mode // ""' <<< "$identity")" \
               "ssid" "$(jq -r '.ssid // ""' <<< "$identity")" \
               "fw" "$(jq -r .fw <<< "$identity")" "auth" "$(jq -r .auth <<< "$identity")" \
               "last_seen_at" "$now" >&2

    echo "$id"
}

# --- _scan_report_missing ---
# @desc_short  : Lists inventory devices in the scanned ranges that did not answer.
# @usage       : _scan_report_missing <found-mac…>
# @notes       : Battery devices (H&T, door sensors) sleep and only wake to report.
# ==============================================================================
function _scan_report_missing {
    local macs_found=" $* "
    local id mac ip last_seen

    # Every inventory device that was not among the answers
    while IFS=$'\x1f' read -r id mac ip last_seen; do
        [[ "$macs_found" == *" ${mac} "* ]] && continue
        WARN "missing: ${id} (${ip}) — last seen ${last_seen:-never}"
    done < <(shelly_sql "SELECT id, mac, ip, last_seen_at FROM ${TABLE_SHELLY} ORDER BY id;")
}

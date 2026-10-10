#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Single values of one, several or all devices.
# @desc_detailed    : --field takes the common values of the normalised status
#                     (same names for Gen1 and Gen2+) and inventory facts; --path
#                     reads anything from the raw API answer. Devices are queried in
#                     parallel. Output: bare value (one device, one value), table or
#                     JSON. Offline devices show "offline" in every live column.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates the request, collects the values and prints them.
# ==============================================================================
function extension_start {
    local -a fields=("${ARG_FIELD[@]}") paths=("${ARG_PATH[@]}")
    local -a ids=()
    local -A summary_by_id=() raw_by_id=()
    local where id answer flag_live=0 name_field

    # Without a value there is nothing to print
    if (( ${#fields[@]} == 0 && ${#paths[@]} == 0 )); then
        ERROR "Nothing to get — use --field <name…> and/or --path <status.…|config.…>."
        return 1
    fi

    # Typos in field names would silently print empty columns
    for name_field in "${fields[@]}"; do
        if [[ ! " ${LIST_GET_FIELDS} " == *" ${name_field} "* ]]; then
            ERROR "Unknown field '${name_field}' — ${LIST_GET_FIELDS// /, }."
            return 1
        fi
    done

    # Raw paths need the device itself — the cache only holds the summary
    if [[ -n "$ARG_CACHED" ]] && (( ${#paths[@]} )); then
        ERROR "--path needs a live answer — drop --cached."
        return 1
    fi

    # Device list → SQL condition over the inventory
    _get_targets ids || return 1
    where="id IN ($(printf "'%s'," "${ids[@]}" | sed 's/,$//'))"

    # Live query only for values the inventory does not hold
    for name_field in "${fields[@]}"; do
        [[ " ${LIST_GET_FIELDS_LIVE} " == *" ${name_field} "* ]] && flag_live=1
    done

    # Normalised status: live (cached on the way) or straight from the cache
    if (( flag_live )) && [[ -z "$ARG_CACHED" ]]; then
        while IFS=$'\x1f' read -r id answer; do
            summary_by_id["$id"]="$answer"
        done < <(shelly_fetch_all "$where")
    fi

    # Raw answers in parallel — fresh bash per device, like the summary workers
    if (( ${#paths[@]} )); then
        _get_raw_all "$where" raw_by_id || return 1
    fi

    _get_output fields paths summary_by_id raw_by_id "$where"
}

# --- _get_globals ---
# @desc_short  : Field names: all known ones and those that need a live answer.
# ==============================================================================
function _get_globals {
    declare -g LIST_GET_FIELDS="online state power energy temp rssi ssid mqtt cloud update uptime ip name room model gen fw mac"
    declare -g LIST_GET_FIELDS_LIVE="online state power energy temp rssi ssid mqtt cloud update uptime"
}
_get_globals

# --- _get_targets ---
# @desc_short  : Resolves 'all' (+ --room) or a comma list into inventory ids.
# @usage       : _get_targets <name-of-id-array>
# ==============================================================================
function _get_targets {
    local -n list_ids="$1"
    local key where_all="1=1"

    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # 'all': every device, optionally of one room
    if [[ "$ARG_DEVICE" == "all" ]]; then
        [[ -n "$ARG_ROOM" ]] && where_all="room='${ARG_ROOM//\'/\'\'}'"
        mapfile -t list_ids < <(shelly_sql "SELECT id FROM ${TABLE_SHELLY} WHERE ${where_all} ORDER BY id;")
    else
        # Comma list: each entry may be id, MAC or IP
        for key in ${ARG_DEVICE//,/ }; do
            shelly_resolve "$key" || return 1
            list_ids+=("$DEV_ID")
        done
    fi

    # Room without match, or an empty inventory
    if (( ${#list_ids[@]} == 0 )); then
        ERROR "No device matches."
        return 1
    fi
}

# --- _get_raw_all ---
# @desc_short  : Fetches the raw status + config of the selected devices in parallel.
# @usage       : _get_raw_all <where> <name-of-map>
# ==============================================================================
function _get_raw_all {
    local where="$1"
    local -n map_raw="$2"
    local id answer

    # Protected devices need the password before the workers start
    if [[ -n $(shelly_sql "SELECT 1 FROM ${TABLE_SHELLY} WHERE (${where}) AND auth=1 LIMIT 1;") ]]; then
        shelly_password || return 1
    fi

    # One worker per device, answers keyed by id
    while IFS=$'\x1f' read -r id answer; do
        map_raw["$id"]="$answer"
    done < <(shelly_sql "SELECT id, ip, gen FROM ${TABLE_SHELLY} WHERE ${where} ORDER BY id;" \
             | tr $'\x1f' ' ' \
             | xargs -r -P "$COUNT_SHELLY_PARALLEL" -n 3 bash -c '_shelly_raw_worker "$@"' _)
}

# --- _get_output ---
# @desc_short  : Builds one JSON object per device and prints value, table or JSON.
# @usage       : _get_output <fields> <paths> <summary-map> <raw-map> <where>
# ==============================================================================
function _get_output {
    local -n list_fields="$1" list_paths="$2" map_summary="$3" map_raw="$4"
    local where="$5"
    local id name room ip model gen fw mac last_status last_seen summary raw
    local json_fields json_paths result="{}"

    json_fields=$(printf '%s\n' "${list_fields[@]}" | jq -R . | jq -sc 'map(select(. != ""))')
    json_paths=$(printf '%s\n' "${list_paths[@]}" | jq -R . | jq -sc 'map(select(. != ""))')

    # One object per device: inventory facts, summary (live/cached/offline), path values
    while IFS=$'\x1f' read -r id name room ip model gen fw mac last_status last_seen; do
        summary="${map_summary[$id]:-}"
        raw="${map_raw[$id]:-null}"
        [[ "$raw" == "offline" ]] && raw="null"

        # --cached (or inventory-only fields): last status, online = seen in the last 15 min
        if [[ -z "$summary" ]]; then
            summary=$(jq -c --arg seen "$last_seen" \
                '(. // {}) + {online: ($seen != "" and (now - ($seen | fromdate)) < 900)}' <<< "${last_status:-null}")
        elif [[ "$summary" == "offline" ]]; then
            summary='{"online":false,"offline":true}'
        fi

        result=$(jq -c --arg id "$id" --argjson s "$summary" --argjson r "$raw" \
            --argjson f "$json_fields" --argjson p "$json_paths" \
            --arg name "$name" --arg room "$room" --arg ip "$ip" --arg model "$model" \
            --arg gen "$gen" --arg fw "$fw" --arg mac "$mac" '
            def state: [($s.outputs // [])[] |
                if .kind == "cover" then "\(.state // "?") \(.pos // "?")%"
                elif .kind == "light" and .on and .brightness != null then "on \(.brightness)%"
                elif .on then "on" else "off" end] | join(",");
            def live(v): if $s.offline then "offline" else v end;
            def field(n):
                if   n == "online" then ($s.online // false)
                elif n == "state"  then live(state)
                elif n == "power"  then live($s.power | if . == null then null else . * 10 | round / 10 end)
                elif n == "energy" then live($s.energy_wh | if . == null then null else . / 1000 * 100 | round / 100 end)
                elif n == "temp"   then live($s.temp)
                elif n == "rssi"   then live($s.rssi)
                elif n == "ssid"   then live($s.ssid)
                elif n == "mqtt"   then live($s.mqtt)
                elif n == "cloud"  then live($s.cloud)
                elif n == "update" then live($s.update)
                elif n == "uptime" then live($s.uptime)
                elif n == "ip"     then $ip
                elif n == "name"   then $name
                elif n == "room"   then $room
                elif n == "model"  then $model
                elif n == "gen"    then ($gen | tonumber? // $gen)
                elif n == "fw"     then $fw
                elif n == "mac"    then $mac
                else null end;
            def rawpath(p): if $r == null then "offline"
                else $r | getpath(p | split(".") | map(tonumber? // .)) end;
            . + {($id): ( reduce $f[] as $n ({}; . + {($n): field($n)})
                        + reduce $p[] as $q ({}; . + {($q): rawpath($q)}) )}' <<< "$result")
    done < <(shelly_sql "SELECT id, name, room, ip, model, gen, fw, mac, last_status, last_seen_at FROM ${TABLE_SHELLY} WHERE ${where} ORDER BY id;")

    _get_print "$result" "$json_fields" "$json_paths"
}

# --- _get_print ---
# @desc_short  : Prints the collected values as bare value, JSON or aligned table.
# @usage       : _get_print <result-json> <fields-json> <paths-json>
# ==============================================================================
function _get_print {
    local result="$1" json_fields="$2" json_paths="$3"
    local count_devices count_values value

    # --json: everything, machine-readable
    if [[ -n "$ARG_JSON" ]]; then
        jq . <<< "$result"
        return 0
    fi

    count_devices=$(jq 'length' <<< "$result")
    count_values=$(jq -n --argjson f "$json_fields" --argjson p "$json_paths" '($f + $p) | length')

    # One device, one value: the bare value — scripts read it without parsing
    if (( count_devices == 1 && count_values == 1 )); then
        value=$(jq -r 'to_entries[0].value | to_entries[0].value | if . == null then "" else tostring end' <<< "$result")
        # A stale or missing answer must not look like a real value
        if [[ "$value" == "offline" ]]; then
            WARN "$(jq -r 'keys[0]' <<< "$result") is offline." >&2
            return 1
        fi
        printf '%s\n' "$value"
        return 0
    fi

    # Table: header = ID + requested names, one row per device
    jq -r --argjson f "$json_fields" --argjson p "$json_paths" '
        (["ID"] + (($f + $p) | map(ascii_upcase))),
        (to_entries[] | [.key] + [ .value | to_entries[] | .value | if . == null then "-" else tostring end ])
        | @tsv' <<< "$result" | column -t -s $'\t'
}

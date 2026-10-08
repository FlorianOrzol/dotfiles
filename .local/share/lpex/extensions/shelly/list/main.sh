#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Overview of all devices — live state, power, network, firmware.
# @desc_detailed    : Queries every selected device in parallel (or uses the cache
#                     with --cached), applies the filters and prints one table in
#                     the chosen view. Offline devices show their last known values,
#                     marked with the time they were last seen.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Collects rows, filters them and prints the table.
# ==============================================================================
function extension_start {
    local view="${ARG_VIEW:-basic}"
    local where="1=1"
    local -A summary_by_id=()
    local id summary
    local -a rows=()

    # Unknown view names are typos — show the valid ones
    if [[ ! "$view" =~ ^(basic|energy|network|firmware)$ ]]; then
        ERROR "Unknown view '${view}' — basic, energy, network or firmware."
        return 1
    fi

    # Empty inventory: point to scan instead of printing an empty table
    if [[ -z $(shelly_sql "SELECT 1 FROM ${TABLE_SHELLY} LIMIT 1;") ]]; then
        INFO "No devices yet — 'lpex shelly scan --add'."
        return 0
    fi

    # Room filter narrows the query itself
    [[ -n "$ARG_ROOM" ]] && where="room='${ARG_ROOM//\'/\'\'}'"

    # Live answers by id; --cached skips the network entirely
    if [[ -z "$ARG_CACHED" ]]; then
        while IFS=$'\x1f' read -r id summary; do
            summary_by_id["$id"]="$summary"
        done < <(shelly_fetch_all "$where")
    fi

    # One TSV row per device that passes the filters
    while IFS= read -r line; do
        rows+=("$line")
    done < <(_list_rows "$view" "$where" summary_by_id)

    _list_print "$view" "${rows[@]}"
}

# --- _list_rows ---
# @desc_short  : Prints one tab-separated row per device in the column set of the view.
# @usage       : _list_rows <view> <where> <name-of-summary-map>
# @desc_detailed: Takes the live summary when there is one, otherwise the cached
#                 last_status (online=false). Filters are applied here.
# ==============================================================================
function _list_rows {
    local view="$1" where="$2"
    local -n map_summary="$3"
    local id name room gen model ip ip_mode ssid fw auth last_seen last_status
    local summary flag_online state power energy temp seen

    # Inventory rows in a stable order: room, then id
    while IFS=$'\x1f' read -r id name room gen model ip ip_mode ssid fw auth last_seen last_status; do
        flag_online=0
        summary="${map_summary[$id]:-}"

        # Live answer = online; otherwise fall back to the cached status
        if [[ -n "$summary" && "$summary" != "offline" ]]; then
            flag_online=1
        else
            summary="${last_status:-}"
        fi
        [[ -z "$summary" ]] && summary='{"outputs":[]}'

        # --cached has no live answers: online means "seen in the last 15 minutes"
        if [[ -n "$ARG_CACHED" && -n "$last_seen" ]] && (( $(date +%s) - $(date -d "$last_seen" +%s) < 900 )); then
            flag_online=1
        fi

        # Online/offline filters
        [[ -n "$ARG_ONLINE"  ]] && (( ! flag_online )) && continue
        [[ -n "$ARG_OFFLINE" ]] && (( flag_online )) && continue

        state=$(shelly_state_text "$summary")

        # On = any output on or any cover open (pos > 0); off = the opposite
        local flag_on
        flag_on=$(jq -r '[.outputs[] | (.on == true) or (.kind == "cover" and (.pos // 0) > 0)] | any' <<< "$summary")
        [[ -n "$ARG_ON"  && "$flag_on" != "true" ]] && continue
        [[ -n "$ARG_OFF" && "$flag_on" == "true" ]] && continue

        power=$(jq -r '.power // empty | . * 10 | round / 10' <<< "$summary")
        energy=$(jq -r '.energy_wh // empty | . / 1000 | . * 100 | round / 100' <<< "$summary")
        temp=$(jq -r '.temp // empty | . * 10 | round / 10' <<< "$summary")

        # Offline rows say since when — the cached values are that old
        if (( flag_online )); then
            seen="online"
        else
            seen="offline${last_seen:+ (seen $(_list_age "$last_seen"))}"
        fi

        # Column set per view; sort key first, removed before printing
        case "$view" in
            basic)
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${room:-~}${id}" "$id" "${ip:--}" "${name:--}" "${room:--}" \
                    "$(shelly_model_text "$model")" "$seen" "${state:--}" "${power:+${power} W}" "${temp:+${temp} °C}" ;;
            energy)
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(LC_ALL=C printf '%012.1f' "${power:-0}")" "$id" "${ip:--}" "${name:--}" "${state:--}" \
                    "${power:-0} W" "${energy:+${energy} kWh}" ;;
            network)
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ip" "$id" "$ip" "${ip_mode:--}" "${ssid:--}" \
                    "$(jq -r '.rssi // empty' <<< "$summary")" \
                    "$(jq -r 'if .mqtt == true then "connected" elif .mqtt == false then "off" else "-" end' <<< "$summary")" \
                    "$(jq -r 'if .cloud == true then "connected" elif .cloud == false then "off" else "-" end' <<< "$summary")" \
                    "$( (( auth )) && echo on || echo OFF)" "$seen" ;;
            firmware)
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(shelly_model_text "$model")${id}" "$id" "${ip:--}" "$(shelly_model_text "$model")" "Gen${gen}" \
                    "$(sed -E 's#^[0-9-]+/##; s#-g[0-9a-f]+$##; s#@.*##' <<< "$fw")" \
                    "$(jq -r '.update // empty | sub("^[0-9-]+/"; "") | sub("-g[0-9a-f]+$"; "")' <<< "$summary")" ;;
        esac
    done < <(shelly_sql "SELECT id, name, room, gen, model, ip, ip_mode, ssid, fw, auth, last_seen_at, last_status FROM ${TABLE_SHELLY} WHERE ${where} ORDER BY room, id;")
}

# --- _list_age ---
# @desc_short  : Human age of a UTC timestamp: "5m ago", "3h ago", "2d ago".
# ==============================================================================
function _list_age {
    local seconds=$(( $(date +%s) - $(date -d "$1" +%s) ))

    # Pick the largest unit that is at least 1
    if (( seconds < 3600 )); then echo "$(( seconds / 60 ))m ago"
    elif (( seconds < 86400 )); then echo "$(( seconds / 3600 ))h ago"
    else echo "$(( seconds / 86400 ))d ago"
    fi
}

# --- _list_print ---
# @desc_short  : Sorts the rows, adds the header and prints an aligned, coloured table.
# @usage       : _list_print <view> <row…>
# ==============================================================================
function _list_print {
    local view="$1"
    shift
    local header sort_opts="-k1,1"
    local c_bold c_red c_green c_yellow c_reset

    # FONT_* hold escape sequences as text (\033[…) — turn them into real control
    # characters, otherwise sed reads \0 as "whole match" and duplicates the text
    c_bold=$(printf '%b' "$FONT_BOLD");     c_reset=$(printf '%b' "$FONT_RESET")
    c_red=$(printf '%b' "$FONT_RED");       c_green=$(printf '%b' "$FONT_GREEN")
    c_yellow=$(printf '%b' "$FONT_YELLOW")

    # Header per view; energy sorts by power, highest first
    case "$view" in
        basic)    header=$'ID\tIP\tNAME\tROOM\tMODEL\tONLINE\tSTATE\tPOWER\tTEMP' ;;
        energy)   header=$'ID\tIP\tNAME\tSTATE\tPOWER\tENERGY'; sort_opts="-k1,1r" ;;
        network)  header=$'ID\tIP\tMODE\tWLAN\tRSSI\tMQTT\tCLOUD\tLOGIN\tONLINE'; sort_opts="-t. -k3,3n -k4,4n" ;;
        firmware) header=$'ID\tIP\tMODEL\tGEN\tFIRMWARE\tUPDATE' ;;
    esac

    # Nothing passed the filters
    if (( $# == 0 )); then
        INFO "No device matches."
        return 0
    fi

    # Sort on the hidden key, drop it, align with column, colour the status words
    {
        printf '%s\n' "$header"
        printf '%s\n' "$@" | sort $sort_opts | cut -f2-
    } | column -t -s $'\t' \
      | sed -E "1s/.*/${c_bold}&${c_reset}/; s/ (offline( \([^)]*\))?)/ ${c_red}\1${c_reset}/; s/ online( |$)/ ${c_green}online${c_reset}\1/; s/ OFF( |$)/ ${c_yellow}OFF${c_reset}\1/"

    echo
    INFO "$# device(s)$( [[ -n "$ARG_CACHED" ]] && echo " — cached values")."
}

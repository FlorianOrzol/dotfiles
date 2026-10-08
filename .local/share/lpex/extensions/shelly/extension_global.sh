#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @meta_author      : Florian Orzol <florian.orzol@gmail.com>
# @meta_version     : 0.2.0
# @meta_date        : 2026-10-06
#
# @desc_short       : Shared DB, HTTP and Gen1/Gen2 translation layer of the shelly extension.
# @desc_detailed    : Inventory lives in shelly.db (one row per device, MAC unique,
# @desc_detailed    : id = slug of the name = later MQTT login). Live data always
# @desc_detailed    : comes from the device HTTP API; the last answer is cached in
# @desc_detailed    : the row (last_status) for offline devices.
# @desc_detailed    :
# @desc_detailed    : Gen1 (/status, /settings) and Gen2+ (/rpc/Shelly.*) differ
# @desc_detailed    : completely — shelly_summary turns both into one JSON shape:
# @desc_detailed    : {online, outputs[], power, energy_wh, temp, rssi, ssid, ...}
# @desc_detailed    :
# @desc_detailed    : Functions used by --option-cmd or xargs workers run in fresh
# @desc_detailed    : bash processes and are exported (see end of file).
#
# @req_packages     : curl, jq, sqlite3, python3, xargs
# @notes            : Gen2+ code follows the official RPC docs; untested until a
# @notes            : Gen2+ device is online (2026-10-06 only Gen1 in the LAN).
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# Wrapped in a function with declare -g: the completion engine sources this file
# inside a function, plain declarations would turn local there.
# ==============================================================================
function _shelly_globals {
    declare -g FILE_SHELLY_DB="${PATH_EXTENSION_DATA:-$HOME/.local/state/lpex/data/shelly}/shelly.db"   # inventory
    declare -g TABLE_SHELLY="devices"                       # one row per device
    declare -g TIMEOUT_SHELLY_HTTP=3                        # seconds per HTTP request
    declare -g COUNT_SHELLY_PARALLEL=64                     # parallel requests for scan/list
    declare -g IP_SHELLY_AP="192.168.33.1"                  # every Shelly in access-point mode

    # Defaults when config.conf lacks a value
    declare -g SHELLY_SCAN_RANGES="${SHELLY_SCAN_RANGES:-10.0.11.0/24}"
    declare -g SHELLY_AUTH_USER="${SHELLY_AUTH_USER:-admin}"
}
_shelly_globals

# ==============================================================================
# --- Database ---
# ==============================================================================

# --- shelly_db_init ---
# @desc_short       : Creates the inventory table if it does not exist yet.
# ================================================================================
function shelly_db_init {
    # id = CLI key and later MQTT login, mac = hardware identity (survives renames/IP changes)
    lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --create-table \
        --cols "id TEXT PRIMARY KEY, mac TEXT UNIQUE NOT NULL, name TEXT, room TEXT, gen INTEGER, model TEXT, ip TEXT, ip_mode TEXT, ssid TEXT, fw TEXT, auth INTEGER DEFAULT 0, profile TEXT DEFAULT 'default', notes TEXT, added_at TEXT DEFAULT CURRENT_TIMESTAMP, last_seen_at TEXT, last_status TEXT, last_status_at TEXT"
}

# --- shelly_sql ---
# @desc_short       : Runs a query with sqlite3, fields separated by \x1f.
# @usage            : shelly_sql "<SELECT ...>"
# @notes            : Read path for lists and workers — lx db is not available in
#                     xargs/--option-cmd subshells. Writes go through lx db.
# ================================================================================
function shelly_sql {
    local query="$1"

    # No database yet means no devices — empty output, not an error
    [[ -f "$FILE_SHELLY_DB" ]] || return 0
    sqlite3 -separator $'\x1f' "$FILE_SHELLY_DB" "$query" 2>/dev/null
}

# --- get_shelly_devices ---
# @desc_short       : Completion list: "id # name · model · ip".
# ================================================================================
function get_shelly_devices {
    shelly_sql "SELECT id, COALESCE(name,'') || ' · ' || COALESCE(model,'') || ' · ' || COALESCE(ip,'') FROM ${TABLE_SHELLY} ORDER BY id;" \
        | sed $'s/\x1f/ # /'
}

# --- get_shelly_rooms ---
# @desc_short       : Completion list of the rooms in use.
# ================================================================================
function get_shelly_rooms {
    shelly_sql "SELECT DISTINCT room FROM ${TABLE_SHELLY} WHERE room IS NOT NULL AND room <> '' ORDER BY room;"
}

# --- shelly_slug ---
# @desc_short       : Turns a display name into an id: lowercase a-z 0-9 and '-'.
# @usage            : id=$(shelly_slug "Garagentor links")   # → garagentor-links
# ================================================================================
function shelly_slug {
    local text="$1"

    # Umlauts spelled out, everything else non-alphanumeric becomes a dash
    text="${text,,}"
    text="${text//ä/ae}"; text="${text//ö/oe}"; text="${text//ü/ue}"; text="${text//ß/ss}"
    text=$(sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' <<< "$text")
    echo "$text"
}

# --- shelly_unique_id ---
# @desc_short       : Returns a free id based on a wanted one (adds -2, -3 … on collision).
# @usage            : id=$(shelly_unique_id <wanted> [own_mac])
# @parameter        : $2 | own_mac | The device's own row does not count as collision
# ================================================================================
function shelly_unique_id {
    local wanted="$1"
    local own_mac="${2:-}"
    local candidate="$wanted"
    local count=2

    # Try the wanted id, then numbered variants until one is free
    while [[ -n $(shelly_sql "SELECT 1 FROM ${TABLE_SHELLY} WHERE id='${candidate}' AND mac<>'${own_mac}';") ]]; do
        candidate="${wanted}-${count}"
        (( count++ ))
    done
    echo "$candidate"
}

# --- shelly_resolve ---
# @desc_short       : Loads one device row into DEV_* globals; accepts id, MAC or IP.
# @usage            : shelly_resolve <id|mac|ip> || return 1
# ================================================================================
function shelly_resolve {
    local key="$1"
    local row

    # One lookup over the three ways people refer to a device
    row=$(shelly_sql "SELECT id, mac, name, room, gen, model, ip, ip_mode, ssid, fw, auth, profile, notes, last_seen_at FROM ${TABLE_SHELLY} WHERE id='${key//\'/\'\'}' OR mac=upper('${key//\'/\'\'}') OR ip='${key//\'/\'\'}' LIMIT 1;")
    if [[ -z "$row" ]]; then
        ERROR "Unknown device '${key}' — see 'lpex shelly list' or 'lpex shelly scan --add'."
        return 1
    fi

    IFS=$'\x1f' read -r DEV_ID DEV_MAC DEV_NAME DEV_ROOM DEV_GEN DEV_MODEL DEV_IP DEV_IP_MODE DEV_SSID DEV_FW DEV_AUTH DEV_PROFILE DEV_NOTES DEV_LAST_SEEN <<< "$row"
}

# ==============================================================================
# --- HTTP ---
# ==============================================================================

# --- shelly_secret ---
# @desc_short       : Prints a password: from the environment, otherwise from the config command.
# @usage            : pw=$(shelly_secret auth|mqtt|wifi) || return 1
# @desc_detailed    : auth → SHELLY_AUTH_PASSWORD or SHELLY_AUTH_PASS_CMD
#                     mqtt → SHELLY_MQTT_PASSWORD or SHELLY_MQTT_PASS_CMD
#                     wifi → SHELLY_WIFI_PASSWORD or SHELLY_WIFI_PASS_CMD
#                     The environment wins — scripts and tests pass a password
#                     without touching rbw. The command runs only when needed.
# ================================================================================
function shelly_secret {
    local kind="${1^^}"
    local name_env="SHELLY_${kind}_PASSWORD"
    local name_cmd="SHELLY_${kind}_PASS_CMD"
    local secret

    # Already known (environment or an earlier call in this run)
    if [[ -n "${!name_env:-}" ]]; then
        printf '%s' "${!name_env}"
        return 0
    fi

    # Without a command there is no source for the password
    if [[ -z "${!name_cmd:-}" ]]; then
        ERROR "${name_cmd} missing in config — lpex --config shelly (or set ${name_env})"
        return 1
    fi

    secret=$(bash -c "${!name_cmd}" 2>/dev/null </dev/null)
    if [[ -z "$secret" ]]; then
        ERROR "Password command returned nothing: ${!name_cmd}"
        return 1
    fi
    printf '%s' "$secret"
}

# --- shelly_password ---
# @desc_short       : Exports SHELLY_AUTH_PASSWORD once, for shelly_http and the workers.
# @notes            : Called only when a device has auth enabled — rbw is not touched otherwise.
# ================================================================================
function shelly_password {
    # Already exported in this run
    [[ -n "${SHELLY_AUTH_PASSWORD:-}" ]] && return 0

    SHELLY_AUTH_PASSWORD=$(shelly_secret auth) || return 1
    export SHELLY_AUTH_PASSWORD
}

# --- _shelly_curl ---
# @desc_short       : One HTTP request to a device; logs in when the device demands it.
# @usage            : _shelly_curl <gen> <url> [curl args…]
# @parameter        : $1 | gen | 1 = basic auth, 2+ = digest auth (only used after a 401)
# @notes            : Credentials go to curl via stdin (-K -), never on the command line.
#                     Prints the body; returns 1 on anything but HTTP 200.
# ================================================================================
function _shelly_curl {
    local gen="$1"
    local url="$2"
    shift 2
    local code body mode_auth="--basic"

    # First try without login — open devices and /shelly need none
    body=$(curl -s -m "$TIMEOUT_SHELLY_HTTP" "$@" -w $'\n%{http_code}' "$url" 2>/dev/null) || return 1
    code="${body##*$'\n'}"
    body="${body%$'\n'*}"

    # 401 = login needed: retry once with the device password
    if [[ "$code" == "401" && -n "${SHELLY_AUTH_PASSWORD:-}" ]]; then
        (( gen >= 2 )) && mode_auth="--digest"
        body=$(printf 'user = "%s:%s"\n' "$SHELLY_AUTH_USER" "$SHELLY_AUTH_PASSWORD" \
                 | curl -s -m "$TIMEOUT_SHELLY_HTTP" "$mode_auth" -K - "$@" -w $'\n%{http_code}' "$url" 2>/dev/null) || return 1
        code="${body##*$'\n'}"
        body="${body%$'\n'*}"
    fi

    # Only a 200 carries a usable answer; the body of an error goes to stderr
    if [[ "$code" != "200" ]]; then
        [[ -n "$body" ]] && printf '%s\n' "HTTP ${code}: ${body}" >&2
        return 1
    fi
    printf '%s' "$body"
}

# --- shelly_http ---
# @desc_short       : GET on a device path.
# @usage            : shelly_http <ip> <path> [gen]
# ================================================================================
function shelly_http {
    local ip="$1"
    local path="$2"
    local gen="${3:-1}"

    _shelly_curl "$gen" "http://${ip}${path}"
}

# --- shelly_set1 ---
# @desc_short       : Gen1 write: GET <path>?key=value&… with URL-encoded values.
# @usage            : shelly_set1 <ip> <path> key=value [key=value…]
# ================================================================================
function shelly_set1 {
    local ip="$1"
    local path="$2"
    shift 2
    local pair
    local -a args=(-G)

    # Every pair is encoded on its own — spaces and umlauts in names survive
    for pair in "$@"; do
        args+=(--data-urlencode "$pair")
    done

    _shelly_curl 1 "http://${ip}${path}" "${args[@]}"
}

# --- shelly_rpc ---
# @desc_short       : Gen2+ RPC call via POST /rpc; prints .result, fails on .error.
# @usage            : shelly_rpc <ip> <method> [params-json]
# ================================================================================
function shelly_rpc {
    local ip="$1"
    local method="$2"
    local params="${3:-{\}}"
    local answer

    answer=$(_shelly_curl 2 "http://${ip}/rpc" -H 'Content-Type: application/json' \
                 -d "$(jq -cn --arg m "$method" --argjson p "$params" '{id: 1, method: $m, params: $p}')") || return 1

    # JSON-RPC errors arrive with HTTP 200 — check the body
    if jq -e '.error' <<< "$answer" >/dev/null 2>&1; then
        printf '%s\n' "RPC ${method}: $(jq -r '.error.message // .error' <<< "$answer")" >&2
        return 1
    fi
    jq -c '.result // {}' <<< "$answer"
}

# --- shelly_identity ---
# @desc_short       : Prints the identity of the device at <ip> as one JSON object.
# @usage            : shelly_identity <ip>
# @desc_detailed    : {mac, gen, model, name, fw, auth, ip_mode, ssid} — /shelly needs
#                     no login on any generation; name/ip_mode/ssid need the config.
# ================================================================================
function shelly_identity {
    local ip="$1"
    local info gen config

    info=$(shelly_http "$ip" "/shelly") || return 1

    # Gen2+ report "gen", Gen1 do not
    gen=$(jq -r '.gen // 1' <<< "$info" 2>/dev/null) || return 1

    if (( gen >= 2 )); then
        config=$(shelly_http "$ip" "/rpc/Shelly.GetConfig" "$gen")
        jq -cn --argjson i "$info" --argjson c "${config:-null}" '{
            mac: ($i.mac | ascii_upcase), gen: $i.gen, model: ($i.app // $i.model),
            name: ($c.sys.device.name // $i.name // null), fw: ($i.ver // $i.fw_id),
            auth: (if $i.auth_en then 1 else 0 end),
            ip_mode: ($c.wifi.sta.ipv4mode // null), ssid: ($c.wifi.sta.ssid // null) }'
    else
        config=$(shelly_http "$ip" "/settings" 1)
        jq -cn --argjson i "$info" --argjson c "${config:-null}" '{
            mac: ($i.mac | ascii_upcase), gen: 1, model: $i.type,
            name: ($c.name // null), fw: $i.fw,
            auth: (if $i.auth then 1 else 0 end),
            ip_mode: ($c.wifi_sta.ipv4_method // null), ssid: ($c.wifi_sta.ssid // null) }'
    fi
}

# --- shelly_summary ---
# @desc_short       : Prints the live status of a device in the common JSON shape.
# @usage            : shelly_summary <ip> <gen>
# @desc_detailed    : {online, outputs:[{kind,on,brightness,pos,state}], power, energy_wh,
#                     temp, rssi, ssid, mqtt, cloud, update, uptime}
#                     Gen1 energy counters are watt-minutes — divided by 60.
# ================================================================================
function shelly_summary {
    local ip="$1"
    local gen="${2:-1}"
    local status

    if (( gen >= 2 )); then
        status=$(shelly_http "$ip" "/rpc/Shelly.GetStatus" "$gen") || return 1
        jq -c '
            [to_entries[] | select(.key | test("^(switch|light|cover):"))] as $c |
            {online: true,
             outputs: [ $c[] | {kind: (.key|split(":")[0]),
                                on: (.value.output // null),
                                brightness: (.value.brightness // null),
                                pos: (.value.current_pos // null),
                                state: (.value.state // null)} ],
             power: ([ $c[].value.apower // 0 ] | add // 0),
             energy_wh: ([ $c[].value.aenergy.total // 0 ] | add // 0),
             temp: ([ $c[].value.temperature.tC // empty ] + [ .["temperature:0"].tC // empty ] | first // null),
             rssi: .wifi.rssi, ssid: .wifi.ssid,
             mqtt: .mqtt.connected, cloud: .cloud.connected,
             update: (.sys.available_updates.stable.version // null),
             uptime: .sys.uptime }' <<< "$status"
    else
        status=$(shelly_http "$ip" "/status" 1) || return 1
        jq -c '
            {online: true,
             outputs: ( [ (.relays // [])[] | {kind: "switch", on: .ison, brightness: null, pos: null, state: null} ]
                      + [ (.lights // [])[] | {kind: "light", on: .ison, brightness: .brightness, pos: null, state: null} ]
                      + [ (.rollers // [])[] | {kind: "cover", on: null, brightness: null, pos: .current_pos, state: .state} ] ),
             power: ([ (.meters // [])[].power ] | add // 0),
             energy_wh: (([ (.meters // [])[].total ] | add // 0) / 60),
             temp: (.tmp.tC // .temperature // null),
             rssi: .wifi_sta.rssi, ssid: .wifi_sta.ssid,
             mqtt: .mqtt.connected, cloud: .cloud.connected,
             update: (if .update.has_update then .update.new_version else null end),
             uptime: .uptime }' <<< "$status"
    fi
}

# --- _shelly_fetch_worker ---
# @desc_short       : xargs worker: prints "id \x1f summary-json" or "id \x1f offline".
# @usage            : _shelly_fetch_worker <id> <ip> <gen>
# ================================================================================
function _shelly_fetch_worker {
    local id="$1" ip="$2" gen="$3"
    local summary

    # An unreachable device is a result too — the caller marks it offline
    summary=$(shelly_summary "$ip" "$gen") || summary="offline"
    printf '%s\x1f%s\n' "$id" "$summary"
}

# --- shelly_fetch_all ---
# @desc_short       : Fetches the live status of many devices in parallel and caches it.
# @usage            : shelly_fetch_all <where-clause>   # e.g. "1=1" or "room='Garten'"
# @desc_detailed    : Prints "id \x1f json|offline" per device and writes online answers
#                     to last_status / last_seen_at. Asks for the device password only
#                     when a selected device has auth enabled.
# ================================================================================
function shelly_fetch_all {
    local where="${1:-1=1}"
    local id summary now

    # Fetch the password once if any selected device is protected
    if [[ -n $(shelly_sql "SELECT 1 FROM ${TABLE_SHELLY} WHERE (${where}) AND auth=1 LIMIT 1;") ]]; then
        shelly_password || return 1
    fi

    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Workers run in fresh bash processes — they only see exported functions/variables
    while IFS=$'\x1f' read -r id summary; do
        printf '%s\x1f%s\n' "$id" "$summary"

        # Cache only real answers; an offline device keeps its last known state
        if [[ "$summary" != "offline" ]]; then
            lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "id='${id}'" \
                --data "last_status" "$summary" "last_status_at" "$now" "last_seen_at" "$now"
        fi
    done < <(shelly_sql "SELECT id, ip, gen FROM ${TABLE_SHELLY} WHERE ${where} ORDER BY id;" \
             | tr $'\x1f' ' ' \
             | xargs -r -P "$COUNT_SHELLY_PARALLEL" -n 3 bash -c '_shelly_fetch_worker "$@"' _)
}

# --- shelly_expand_ranges ---
# @desc_short       : Prints every host address of the given CIDR ranges.
# @usage            : shelly_expand_ranges "10.0.11.0/24 10.0.12.0/24"
# ================================================================================
function shelly_expand_ranges {
    local ranges="$1"

    # python's ipaddress handles any prefix; larger than /20 is refused (4096 probes)
    python3 - "$ranges" <<'EOF'
import ipaddress, sys
for spec in sys.argv[1].split():
    net = ipaddress.ip_network(spec, strict=False)
    if net.prefixlen < 20:
        sys.exit(f"range {spec} too large (max /20)")
    for host in net.hosts():
        print(host)
EOF
}

# --- shelly_next_free_ip ---
# @desc_short       : Prints the first address of a range that is neither in the inventory nor answers ping.
# @usage            : ip=$(shelly_next_free_ip 10.0.11.0/24)
# @notes            : Checks the first 64 inventory-free addresses in parallel (1 s each);
#                     a device that is switched off would still look free — confirm it.
# ================================================================================
function shelly_next_free_ip {
    local range="$1"
    local used candidate

    used=" $(shelly_sql "SELECT ip FROM ${TABLE_SHELLY};" | tr '\n' ' ') "

    # Inventory-free candidates in address order, pinged in parallel, lowest silent one wins
    shelly_expand_ranges "$range" \
        | while IFS= read -r candidate; do [[ "$used" == *" ${candidate} "* ]] || echo "$candidate"; done \
        | head -64 \
        | xargs -r -P 64 -I{} sh -c 'ping -c1 -W1 {} >/dev/null 2>&1 || echo {}' \
        | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | head -1
}

# --- _shelly_probe_worker ---
# @desc_short       : xargs worker: prints "ip \x1f identity-json" for Shellys, nothing otherwise.
# ================================================================================
function _shelly_probe_worker {
    local ip="$1"
    local identity

    # /shelly answers fast on every generation — silence for non-Shellys
    identity=$(shelly_identity "$ip" 2>/dev/null) || return 0
    printf '%s\x1f%s\n' "$ip" "$identity"
}

# ==============================================================================
# --- Operations ---
# One function per action, same arguments for every generation. Each prints the
# device answer (JSON) on success and returns 1 on failure. Gen1 settings take
# effect at once; Gen1 MQTT changes need a reboot (callers handle that).
# ==============================================================================

# --- shelly_output_kind ---
# @desc_short       : Prints the kind of output <channel>: switch | light | cover.
# @usage            : kind=$(shelly_output_kind <ip> <gen> <channel>)
# ================================================================================
function shelly_output_kind {
    local ip="$1" gen="$2" channel="${3:-0}"

    # The summary already lists the outputs in device order
    shelly_summary "$ip" "$gen" | jq -r --argjson c "$channel" '.outputs[$c].kind // empty'
}

# --- shelly_op_name ---
# @desc_short       : Sets the device name (shown in the Shelly UI and apps).
# ================================================================================
function shelly_op_name {
    local ip="$1" gen="$2" name="$3"

    if (( gen >= 2 )); then
        shelly_rpc "$ip" "Sys.SetConfig" "$(jq -cn --arg n "$name" '{config: {device: {name: $n}}}')"
    else
        shelly_set1 "$ip" "/settings" "name=${name}"
    fi
}

# --- shelly_op_cloud ---
# @desc_short       : Shelly cloud on (1) or off (0).
# ================================================================================
function shelly_op_cloud {
    local ip="$1" gen="$2" enable="$3"

    if (( gen >= 2 )); then
        shelly_rpc "$ip" "Cloud.SetConfig" "$(jq -cn --argjson e "$( (( enable )) && echo true || echo false)" '{config: {enable: $e}}')"
    else
        shelly_set1 "$ip" "/settings/cloud" "enabled=${enable}"
    fi
}

# --- shelly_op_mqtt ---
# @desc_short       : MQTT on/off; on = server, login (= device id), password, prefix.
# @usage            : shelly_op_mqtt <ip> <gen> <0|1> [server] [id] [password] [prefix]
# @notes            : Gen1 publishes below shellies/<hostname> with the hostname as client id
#                     (custom mqtt_id is ignored by fw 1.14) — the broker ACL matches it via
#                     %c. Gen2+ use topic_prefix (home/device/<id>).
#                     Gen1: MQTT and Shelly cloud exclude each other; reboot needed.
# ================================================================================
function shelly_op_mqtt {
    local ip="$1" gen="$2" enable="$3" server="${4:-}" id="${5:-}" password="${6:-}" prefix="${7:-}"

    # Switching off needs no connection data
    if (( ! enable )); then
        if (( gen >= 2 )); then
            shelly_rpc "$ip" "MQTT.SetConfig" '{"config":{"enable":false}}'
        else
            shelly_set1 "$ip" "/settings" "mqtt_enable=false"
        fi
        return
    fi

    if (( gen >= 2 )); then
        shelly_rpc "$ip" "MQTT.SetConfig" "$(jq -cn --arg s "$server" --arg u "$id" --arg p "$password" --arg t "$prefix" \
            '{config: {enable: true, server: $s, user: $u, pass: $p, client_id: $u, topic_prefix: $t}}')"
    else
        # No mqtt_id: Gen1 firmware ignores it (topics stay shellies/<hostname>)
        shelly_set1 "$ip" "/settings" "mqtt_enable=true" "mqtt_server=${server}" \
            "mqtt_user=${id}" "mqtt_pass=${password}"
    fi
}

# --- shelly_op_auth ---
# @desc_short       : Device login on (1, with user + password) or off (0).
# @notes            : Gen2+ store a digest hash: ha1 = sha256("user:realm:password"),
#                     realm = device id from /shelly. Afterwards every request needs
#                     the password — callers export SHELLY_AUTH_PASSWORD first.
# ================================================================================
function shelly_op_auth {
    local ip="$1" gen="$2" enable="$3" user="${4:-$SHELLY_AUTH_USER}" password="${5:-}"
    local realm ha1

    if (( gen >= 2 )); then
        realm=$(shelly_http "$ip" "/shelly" "$gen" | jq -r '.id') || return 1

        # ha1 = null removes the login
        if (( enable )); then
            ha1=$(printf '%s' "${user}:${realm}:${password}" | sha256sum | cut -d' ' -f1)
            shelly_rpc "$ip" "Shelly.SetAuth" "$(jq -cn --arg u "$user" --arg r "$realm" --arg h "$ha1" '{user: $u, realm: $r, ha1: $h}')"
        else
            shelly_rpc "$ip" "Shelly.SetAuth" "$(jq -cn --arg u "$user" --arg r "$realm" '{user: $u, realm: $r, ha1: null}')"
        fi
    else
        if (( enable )); then
            shelly_set1 "$ip" "/settings/login" "enabled=1" "username=${user}" "password=${password}"
        else
            shelly_set1 "$ip" "/settings/login" "enabled=0"
        fi
    fi
}

# --- shelly_op_wifi ---
# @desc_short       : Joins a WLAN as client — static IP or DHCP.
# @usage            : shelly_op_wifi <ip> <gen> <ssid> <password> static|dhcp [ip mask gw dns]
# @notes            : The device leaves its current network — the answer is the last
#                     thing heard from it at the old address.
# ================================================================================
function shelly_op_wifi {
    local ip="$1" gen="$2" ssid="$3" password="$4" mode="$5"
    local ip_new="${6:-}" mask="${7:-}" gw="${8:-}" dns="${9:-}"

    if (( gen >= 2 )); then
        shelly_rpc "$ip" "WiFi.SetConfig" "$(jq -cn --arg s "$ssid" --arg p "$password" --arg m "$mode" \
            --arg i "$ip_new" --arg n "$mask" --arg g "$gw" --arg d "$dns" \
            '{config: {sta: ({ssid: $s, pass: $p, enable: true, ipv4mode: $m}
                + (if $m == "static" then {ip: $i, netmask: $n, gw: $g, nameserver: $d} else {} end))}}')"
    else
        local -a params=("enabled=1" "ssid=${ssid}" "key=${password}" "ipv4_method=${mode}")

        # Static addressing needs the full set, DHCP none of it
        if [[ "$mode" == "static" ]]; then
            params+=("ip=${ip_new}" "netmask=${mask}" "gateway=${gw}" "dns=${dns}")
        fi
        shelly_set1 "$ip" "/settings/sta" "${params[@]}"
    fi
}

# --- shelly_op_default_state ---
# @desc_short       : Power-on behaviour of an output: on | off | last | switch.
# @usage            : shelly_op_default_state <ip> <gen> <channel> <state>
# @notes            : switch = follow the wall switch (Gen1 'switch', Gen2 'match_input').
# ================================================================================
function shelly_op_default_state {
    local ip="$1" gen="$2" channel="$3" state="$4"
    local kind

    kind=$(shelly_output_kind "$ip" "$gen" "$channel")

    if (( gen >= 2 )); then
        local state_rpc="$state"
        [[ "$state" == "last" ]] && state_rpc="restore_last"
        [[ "$state" == "switch" ]] && state_rpc="match_input"
        local method="Switch.SetConfig"
        [[ "$kind" == "light" ]] && method="Light.SetConfig"
        shelly_rpc "$ip" "$method" "$(jq -cn --argjson i "$channel" --arg s "$state_rpc" '{id: $i, config: {initial_state: $s}}')"
    else
        # Gen1 keeps relays and lights in separate setting trees
        local tree="relay"
        [[ "$kind" == "light" ]] && tree="light"
        shelly_set1 "$ip" "/settings/${tree}/${channel}" "default_state=${state}"
    fi
}

# --- shelly_op_switch ---
# @desc_short       : Switches an output: on | off | toggle, lights optionally with brightness.
# @usage            : shelly_op_switch <ip> <gen> <channel> <on|off|toggle> [brightness]
# ================================================================================
function shelly_op_switch {
    local ip="$1" gen="$2" channel="$3" action="$4" brightness="${5:-}"
    local kind

    kind=$(shelly_output_kind "$ip" "$gen" "$channel")

    # Covers are no switches — 'shelly cover' moves them
    if [[ "$kind" == "cover" ]]; then
        echo "output ${channel} is a cover — use 'lpex shelly cover'" >&2
        return 1
    fi
    if [[ -z "$kind" ]]; then
        echo "no output ${channel} on this device" >&2
        return 1
    fi

    if (( gen >= 2 )); then
        local component="Switch"
        [[ "$kind" == "light" ]] && component="Light"

        # Toggle is its own method; on/off (+brightness) go through Set
        if [[ "$action" == "toggle" ]]; then
            shelly_rpc "$ip" "${component}.Toggle" "$(jq -cn --argjson i "$channel" '{id: $i}')"
        else
            shelly_rpc "$ip" "${component}.Set" "$(jq -cn --argjson i "$channel" --argjson o "$( [[ "$action" == "on" ]] && echo true || echo false)" \
                --arg b "$brightness" '{id: $i, on: $o} + (if $b != "" then {brightness: ($b|tonumber)} else {} end)')"
        fi
    else
        local -a params=("turn=${action}")
        [[ -n "$brightness" && "$kind" == "light" ]] && params+=("brightness=${brightness}")
        shelly_set1 "$ip" "/${kind/switch/relay}/${channel}" "${params[@]}"
    fi
}

# --- shelly_op_cover ---
# @desc_short       : Moves a cover: open | close | stop | <0-100> (position).
# ================================================================================
function shelly_op_cover {
    local ip="$1" gen="$2" action="$3" channel="${4:-0}"

    if (( gen >= 2 )); then
        case "$action" in
            open)  shelly_rpc "$ip" "Cover.Open"  "{\"id\":${channel}}" ;;
            close) shelly_rpc "$ip" "Cover.Close" "{\"id\":${channel}}" ;;
            stop)  shelly_rpc "$ip" "Cover.Stop"  "{\"id\":${channel}}" ;;
            *)     shelly_rpc "$ip" "Cover.GoToPosition" "{\"id\":${channel},\"pos\":${action}}" ;;
        esac
    else
        # A number moves to that position, a word is a direction
        if [[ "$action" =~ ^[0-9]+$ ]]; then
            shelly_set1 "$ip" "/roller/${channel}" "go=to_pos" "roller_pos=${action}"
        else
            shelly_set1 "$ip" "/roller/${channel}" "go=${action}"
        fi
    fi
}

# --- shelly_op_update_check ---
# @desc_short       : Asks the device for new firmware; prints "<current> <new|none>".
# ================================================================================
function shelly_op_update_check {
    local ip="$1" gen="$2"
    local info

    if (( gen >= 2 )); then
        info=$(shelly_rpc "$ip" "Shelly.CheckForUpdate") || return 1
        printf '%s %s\n' "$(shelly_http "$ip" "/shelly" "$gen" | jq -r '.ver')" "$(jq -r '.stable.version // "none"' <<< "$info")"
    else
        # Trigger a fresh check, then read the result from /status
        shelly_http "$ip" "/ota/check" 1 >/dev/null
        sleep 2
        shelly_http "$ip" "/status" 1 | jq -r '"\(.update.old_version) \(if .update.has_update then .update.new_version else "none" end)"'
    fi
}

# --- shelly_op_update_run ---
# @desc_short       : Starts the firmware update (device reboots, ~1 minute).
# ================================================================================
function shelly_op_update_run {
    local ip="$1" gen="$2"

    if (( gen >= 2 )); then
        shelly_rpc "$ip" "Shelly.Update" '{"stage":"stable"}'
    else
        shelly_set1 "$ip" "/ota" "update=true"
    fi
}

# --- shelly_op_reboot ---
# @desc_short       : Restarts the device.
# ================================================================================
function shelly_op_reboot {
    local ip="$1" gen="$2"

    if (( gen >= 2 )); then
        shelly_rpc "$ip" "Shelly.Reboot"
    else
        shelly_http "$ip" "/reboot" 1
    fi
}

# --- shelly_config_flat ---
# @desc_short       : Prints the device configuration as "path = value" lines.
# @notes            : Secrets (pass, key, password, ha1) are masked.
# ================================================================================
function shelly_config_flat {
    local ip="$1" gen="$2"
    local config

    if (( gen >= 2 )); then
        config=$(shelly_rpc "$ip" "Shelly.GetConfig") || return 1
    else
        config=$(shelly_http "$ip" "/settings" 1) || return 1
    fi

    # Every scalar with its dotted path; secrets never reach the terminal
    # paths(scalars) would drop false/null — it uses the value itself as condition
    jq -r 'paths(type != "object" and type != "array") as $p
           | ($p | map(tostring) | join(".")) as $k
           | "\($k) = \(if ($k | test("(pass|key|password|ha1)$")) then "***" else getpath($p) end)"' <<< "$config"
}

# --- shelly_profile_value ---
# @desc_short       : Value of a profile key: SHELLY_PROFILE_<P>_<KEY>, else SHELLY_DEFAULT_<KEY>.
# @usage            : v=$(shelly_profile_value <profile> AUTH|CLOUD|MQTT)
# ================================================================================
function shelly_profile_value {
    local profile="${1:-default}" key="$2"
    local name_profile="SHELLY_PROFILE_${profile^^}_${key}"
    local name_default="SHELLY_DEFAULT_${key}"

    # Dashes are not allowed in variable names — garden-pumps → GARDEN_PUMPS
    name_profile="${name_profile//-/_}"
    echo "${!name_profile:-${!name_default:-0}}"
}

# --- shelly_mqtt_account ---
# @desc_short       : Creates/updates the broker account of a device via SHELLY_MQTT_ACCOUNT_CMD.
# @usage            : shelly_mqtt_account <id> <password>
# @notes            : The template gets {id}; the password goes in on stdin, so it shows
#                     neither in the terminal nor in a process list. A template with
#                     {password} still works (filled in quoted). Empty = managed elsewhere.
# ================================================================================
function shelly_mqtt_account {
    local id="$1" password="$2"
    local cmd="${SHELLY_MQTT_ACCOUNT_CMD:-}"

    # No template configured — the broker account is the user's business
    if [[ -z "$cmd" ]]; then
        WARN "SHELLY_MQTT_ACCOUNT_CMD empty — create the broker account '${id}' yourself."
        return 0
    fi

    # Values go in shell-quoted, the template stays readable in the config
    cmd="${cmd//\{id\}/"$(printf '%q' "$id")"}"

    # Old-style template with the password as argument
    if [[ "$cmd" == *"{password}"* ]]; then
        cmd="${cmd//\{password\}/"$(printf '%q' "$password")"}"
        bash -c "$cmd" </dev/null
        return
    fi

    printf '%s\n' "$password" | bash -c "$cmd"
}

# --- shelly_apply_profile ---
# @desc_short       : Applies a profile (cloud, MQTT, login) to one device.
# @usage            : shelly_apply_profile <id> <ip> <gen> <profile> [only] [no_reboot]
# @parameter        : $5 | only      | Comma list of parts: cloud,mqtt,auth (default: all)
# @parameter        : $6 | no_reboot | 1 = caller reboots itself (config set combines steps)
# @desc_detailed    : Order: cloud → MQTT (broker account first) → login last, because
#                     every request after the login change needs the password. Gen1
#                     reboots after an MQTT change. Updates auth/profile in the inventory.
# ================================================================================
function shelly_apply_profile {
    local id="$1" ip="$2" gen="$3" profile="${4:-default}" only="${5:-cloud,mqtt,auth}" flag_no_reboot="${6:-0}"
    local want_cloud want_mqtt want_auth flag_reboot=0 password_mqtt password_auth prefix

    want_cloud=$(shelly_profile_value "$profile" CLOUD)
    want_mqtt=$(shelly_profile_value "$profile" MQTT)
    want_auth=$(shelly_profile_value "$profile" AUTH)

    # Gen1 cannot run MQTT and the Shelly cloud together
    if (( gen == 1 && want_cloud && want_mqtt )) && [[ ",$only," == *,cloud,* && ",$only," == *,mqtt,* ]]; then
        WARN "${id}: Gen1 cannot use cloud and MQTT together — cloud stays off."
        want_cloud=0
    fi

    # 1. Cloud
    if [[ ",$only," == *,cloud,* ]]; then
        shelly_op_cloud "$ip" "$gen" "$want_cloud" >/dev/null || { ERROR "${id}: cloud setting failed"; return 1; }
        OK "${id}: cloud $( (( want_cloud )) && echo on || echo off)"
    fi

    # 2. MQTT — the broker account must exist before the device tries to log in
    if [[ ",$only," == *,mqtt,* ]]; then
        if (( want_mqtt )); then
            password_mqtt=$(shelly_secret mqtt) || return 1
            shelly_mqtt_account "$id" "$password_mqtt" || { ERROR "${id}: broker account failed"; return 1; }
            prefix="${SHELLY_MQTT_PREFIX//\{id\}/$id}"
            shelly_op_mqtt "$ip" "$gen" 1 "$SHELLY_MQTT_SERVER" "$id" "$password_mqtt" "$prefix" >/dev/null \
                || { ERROR "${id}: MQTT setting failed"; return 1; }
            # Gen1 ignores a custom MQTT id — its topics follow the hostname
            local topics="$prefix"
            (( gen == 1 )) && topics="shellies/$(shelly_http "$ip" "/settings" 1 | jq -r '.device.hostname')"
            OK "${id}: MQTT on — ${SHELLY_MQTT_SERVER}, login ${id}, topics ${topics}"
        else
            shelly_op_mqtt "$ip" "$gen" 0 >/dev/null || { ERROR "${id}: MQTT setting failed"; return 1; }
            OK "${id}: MQTT off"
        fi
        (( gen == 1 )) && flag_reboot=1
    fi

    # 3. Login last — afterwards every request needs the password
    if [[ ",$only," == *,auth,* ]]; then
        if (( want_auth )); then
            password_auth=$(shelly_secret auth) || return 1
            shelly_op_auth "$ip" "$gen" 1 "$SHELLY_AUTH_USER" "$password_auth" >/dev/null || { ERROR "${id}: login setting failed"; return 1; }
            export SHELLY_AUTH_PASSWORD="$password_auth"
        else
            shelly_op_auth "$ip" "$gen" 0 >/dev/null || { ERROR "${id}: login setting failed"; return 1; }
        fi
        lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "id='${id}'" --data "auth" "$want_auth"
        OK "${id}: login $( (( want_auth )) && echo "on (${SHELLY_AUTH_USER})" || echo off)"
    fi

    lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "id='${id}'" --data "profile" "$profile"

    # Gen1 picks up MQTT changes only after a restart
    if (( flag_reboot && ! flag_no_reboot )); then
        shelly_op_reboot "$ip" "$gen" >/dev/null && INFO "${id}: rebooting to activate MQTT (~15 s)"
    fi
}

# ==============================================================================
# --- Formatting ---
# ==============================================================================

# --- shelly_state_text ---
# @desc_short       : Short state text of a summary: "on", "off,on", "on 21%", "stop 0%".
# @usage            : shelly_state_text <summary-json>
# ================================================================================
function shelly_state_text {
    jq -r '[.outputs[] |
            if .kind == "cover" then "\(.state // "?") \(.pos // "?")%"
            elif .kind == "light" and .on and .brightness != null then "on \(.brightness)%"
            elif .on then "on" else "off" end] | join(",")' <<< "$1"
}

# --- shelly_model_text ---
# @desc_short       : Readable model name for a Gen1 type code; Gen2+ app names pass through.
# @usage            : shelly_model_text SHPLG-S   # → Plug S
# ================================================================================
function shelly_model_text {
    local model="$1"

    # Gen1 reports type codes, Gen2+ already readable app names (PlusPlugS, Pro4PM …)
    case "$model" in
        SHPLG-S)   echo "Plug S" ;;
        SHPLG-1)   echo "Plug" ;;
        SHPLG2-1)  echo "Plug (2)" ;;
        SHSW-1)    echo "Shelly 1" ;;
        SHSW-PM)   echo "Shelly 1PM" ;;
        SHSW-25)   echo "Shelly 2.5" ;;
        SHSW-21)   echo "Shelly 2" ;;
        SHVIN-1)   echo "Vintage" ;;
        SHBLB-1)   echo "Bulb" ;;
        SHBDUO-1)  echo "Duo" ;;
        SHDM-1)    echo "Dimmer" ;;
        SHDM-2)    echo "Dimmer 2" ;;
        SHHT-1)    echo "H&T" ;;
        SHEM)      echo "EM" ;;
        SHEM-3)    echo "3EM" ;;
        SHRGBW2)   echo "RGBW2" ;;
        SHDW-2)    echo "Door/Window 2" ;;
        SHWT-1)    echo "Flood" ;;
        SHTRV-01)  echo "TRV" ;;
        *)         echo "$model" ;;
    esac
}

# ==============================================================================
# --- Export block ---
# --option-cmd and xargs workers run in fresh bash processes.
# ==============================================================================
export -f shelly_sql get_shelly_devices get_shelly_rooms _shelly_curl shelly_http shelly_identity shelly_summary
export -f _shelly_fetch_worker _shelly_probe_worker shelly_set1 shelly_rpc shelly_output_kind
export FILE_SHELLY_DB TABLE_SHELLY TIMEOUT_SHELLY_HTTP SHELLY_AUTH_USER

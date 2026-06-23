#!/bin/bash
# ==============================================================================
# --- Compact Overview Action ---
# One-pager: device table, zpool health, ZFS sync, HA container status.
# All state data is read from the NFS share — HA IDs fetched once via SSH in main.sh.
# Sourced by main.sh — do not execute directly.
# ==============================================================================

# --- _action_compact ---
# @desc_short       : Prints the compact one-pager status overview.
# @usage            : _action_compact
# ================================================================================
function _action_compact {
    SECTION "HOMELAB STATUS   $(date '+%Y-%m-%d  %H:%M:%S')"

    _compact_section_devices
    _compact_section_snapshots
    _compact_section_containers
    echo
}

# ==============================================================================
# --- Section: Device Table ---
# One compact row per device — custom printf layout; no LPEX table function exists.
# LPEX output functions (INFO/WARN/ERROR) are used for non-table messages.
# ==============================================================================

# --- _compact_section_devices ---
# @desc_short       : Prints a compact device status table for all hosts and observers.
# ================================================================================
function _compact_section_devices {
    SUBSECTION "DEVICES"

    # Column header row — DIM styling since it is metadata, not content
    printf ' %b%-11s  %-14s  %-5s  %-8s  %-3s  %-20s  %-4s  %s%b\n' \
        "${FONT_DIM}" \
        "UPDATED" "DEVICE" "UP" "LAST UPG" "UPG" "MSGS" "MEM" "STORE" \
        "${FONT_RESET}"

    # Iterate all configured hosts; auto-detect pending by checking for state directory
    while IFS=' # ' read -r host_name _rest; do
        local state_dir="${PATH_STATE_HOSTS}/${host_name}"

        # No state directory means this host has not been integrated yet
        if [[ ! -d "${state_dir}" ]]; then
            INFO "${host_name} — not yet integrated"
            continue
        fi
        _compact_device_row "${state_dir}/status.json" "host"
    done < <(get_hosts)

    # Iterate all configured observers
    while IFS=' # ' read -r obs_name _rest; do
        local state_dir="${PATH_STATE_OBSERVERS}/${obs_name}"

        # No state directory means this observer has not been integrated yet
        if [[ ! -d "${state_dir}" ]]; then
            INFO "${obs_name} — not yet integrated"
            continue
        fi
        _compact_device_row "${state_dir}/status.json" "observer"
    done < <(get_observers)

    # Observer heartbeat below the table
    if [[ -f "${FILE_OBSERVER_HEARTBEAT}" ]]; then
        _compact_heartbeat_line
    fi
}

# --- _compact_device_row ---
# @desc_short       : Reads one status.json and prints a single compact table row.
# @usage            : _compact_device_row <file_status_json> <device_type>
# @parameter        : $1 | file_status_json | Absolute path to the device's status.json.
# @parameter        : $2 | device_type      | "host" or "observer".
# ================================================================================
function _compact_device_row {
    local file_status_json="$1"
    local device_type="$2"

    # Missing status.json means the health script never wrote data for this device
    if [[ ! -f "${file_status_json}" ]]; then
        local device_name
        device_name=$(basename "$(dirname "${file_status_json}")")
        WARN "${device_name} — no status.json"
        return
    fi

    # 1. Parse all fields in one jq call to avoid repeated process spawns
    local json_out
    json_out=$(${CMD_JQ} -r '
        [
            .hostname,
            .timestamp,
            (.system.uptime_seconds | floor | tostring),
            (.updates.date_last_upgrade // "unknown"),
            (.updates.count_available_upgrades | tostring),
            (.memory.used_percent | tostring),
            (.journal.count_warnings_errors_0_4 // 0 | tostring),
            (.journal.count_critical_2 // 0 | tostring),
            (.journal.count_emergency_0_1 // 0 | tostring),
            (.journal.count_failed_services // 0 | tostring),
            (.journal.count_oom_kills // 0 | tostring),
            (.storage.zfs_state // "n/a"),
            (.storage.root_usage_percent // 0 | tostring),
            (.storage.state_usage_percent // "" | tostring)
        ] | join("|")
    ' "${file_status_json}")

    # Split pipe-delimited output into named variables
    IFS='|' read -r hostname ts_raw uptime_s date_last_upgrade upg_count \
        mem_pct j_warn j_crit j_emerg j_fail j_oom \
        zfs_state root_pct state_pct <<< "${json_out}"

    # 2. UPDATED — short date-time from the JSON write timestamp
    local updated_str
    updated_str=$(date -d "${ts_raw}" "+%m-%d %H:%M")

    # 3. UP — uptime as single largest unit (183d / 13h / 5m)
    local uptime_str
    uptime_str=$(_status_format_duration_compact "${uptime_s}")

    # 4. LAST UPG — how long ago the last apt upgrade ran
    local last_upg_str
    if [[ "${date_last_upgrade}" == "unknown" ]]; then
        last_upg_str="?"
    else
        local last_upg_epoch
        last_upg_epoch=$(date -d "${date_last_upgrade}" +%s 2>/dev/null)
        if [[ -z "${last_upg_epoch}" ]]; then
            last_upg_str="?"
        else
            local last_upg_secs=$(( $(date +%s) - last_upg_epoch ))
            last_upg_str=$(_status_format_duration_compact "${last_upg_secs}")
        fi
    fi

    # 5. UPG — available package count with threshold coloring
    local upg_color="${FONT_RESET}"
    (( upg_count > 0 ))  && upg_color="${FONT_YELLOW}"
    (( upg_count > 50 )) && upg_color="${FONT_RED}"

    # 6. MSGS — journal summary; visible length tracked manually to avoid sed for padding
    local msgs_str="" msgs_len=0

    if (( j_warn == 0 && j_fail == 0 && j_oom == 0 )); then
        msgs_str="${FONT_DIM}—${FONT_RESET}"
        msgs_len=1
    else
        # Warning count: yellow for any warning, red when critical or emergency also present
        local w_color="${FONT_YELLOW}"
        (( j_crit > 0 || j_emerg > 0 )) && w_color="${FONT_RED}"
        msgs_str+="${w_color}${j_warn}${FONT_RESET}"
        (( msgs_len += ${#j_warn} ))
        # Crit/emerg subset in parens: "12(2/1)" = 12 total, 2 critical, 1 emergency
        if (( j_crit > 0 || j_emerg > 0 )); then
            local sub="(${j_crit}/${j_emerg})"
            msgs_str+="${FONT_RED}${sub}${FONT_RESET}"
            (( msgs_len += ${#sub} ))
        fi
        # Failed systemd services — not part of journal; sourced from systemctl --failed
        if (( j_fail > 0 )); then
            local fl=" ${j_fail}fl"
            msgs_str+="${FONT_YELLOW}${fl}${FONT_RESET}"
            (( msgs_len += ${#fl} ))
        fi
        # OOM kills: kernel terminated processes due to memory exhaustion (hosts only)
        if [[ "${device_type}" == "host" ]] && (( j_oom > 0 )); then
            local oom=" ${j_oom}oom"
            msgs_str+="${FONT_RED}${oom}${FONT_RESET}"
            (( msgs_len += ${#oom} ))
        fi
    fi

    # Pad MSGS to fixed visible width so MEM and STORE columns align after it
    local msgs_pad=$(( 20 - msgs_len ))
    (( msgs_pad > 0 )) && msgs_str+="$(printf '%*s' "${msgs_pad}" '')"

    # 7. MEM — RAM usage percent with threshold coloring
    local mem_color="${FONT_GREEN}"
    (( mem_pct >= 75 )) && mem_color="${FONT_YELLOW}"
    (( mem_pct >= 90 )) && mem_color="${FONT_RED}"

    # 8. STORE — aggregate storage health: OK / WARN / ERROR
    local store_label="OK" store_color="${FONT_GREEN}"
    # ZFS pool not in healthy state counts as error (hosts only; observers report "n/a")
    if [[ "${device_type}" == "host" && "${zfs_state}" != "ok" && "${zfs_state}" != "n/a" ]]; then
        store_label="ERROR"; store_color="${FONT_RED}"
    fi
    # Root partition: WARN ≥80%, ERROR ≥90%
    if (( root_pct >= 90 )); then
        store_label="ERROR"; store_color="${FONT_RED}"
    elif (( root_pct >= 80 )) && [[ "${store_label}" != "ERROR" ]]; then
        store_label="WARN"; store_color="${FONT_YELLOW}"
    fi
    # State partition (observer-specific separate mount)
    if [[ -n "${state_pct}" && "${state_pct}" != "0" ]]; then
        if (( state_pct >= 90 )); then
            store_label="ERROR"; store_color="${FONT_RED}"
        elif (( state_pct >= 80 )) && [[ "${store_label}" != "ERROR" ]]; then
            store_label="WARN"; store_color="${FONT_YELLOW}"
        fi
    fi

    # Print aligned row: UPDATED  DEVICE  UP  LAST UPG  UPG  MSGS  MEM  STORE
    printf ' %-11s  %b%-14s%b  %-5s  %-8s  %b%-3s%b  %s  %b%-4s%b  %b%s%b\n' \
        "${updated_str}" \
        "${FONT_BOLD}"   "${hostname}"      "${FONT_RESET}" \
        "${uptime_str}"  "${last_upg_str}" \
        "${upg_color}"   "${upg_count}"    "${FONT_RESET}" \
        "${msgs_str}" \
        "${mem_color}"   "${mem_pct}%"     "${FONT_RESET}" \
        "${store_color}" "${store_label}"  "${FONT_RESET}"
}

# --- _compact_heartbeat_line ---
# @desc_short       : Prints the observer heartbeat age below the device table.
# ================================================================================
function _compact_heartbeat_line {
    local hb_node hb_ts hb_age hb_age_str
    hb_node=$(${CMD_JQ} -r '.node' "${FILE_OBSERVER_HEARTBEAT}")
    hb_ts=$(${CMD_JQ} -r   '.ts'   "${FILE_OBSERVER_HEARTBEAT}")
    hb_age=$(_status_calc_age_seconds "${hb_ts}")
    hb_age_str=$(_status_format_duration "${hb_age}")

    # Select output level based on heartbeat age: ok <10min, warn <1h, error ≥1h
    if (( hb_age > 3600 )); then
        ERROR "Heartbeat  ${hb_node} — ${hb_ts}  (${hb_age_str} ago)"
    elif (( hb_age > 600 )); then
        WARN  "Heartbeat  ${hb_node} — ${hb_ts}  (${hb_age_str} ago)"
    else
        INFO  "Heartbeat  ${hb_node} — ${hb_ts}  (${hb_age_str} ago)"
    fi
}

# ==============================================================================
# --- Section: ZFS Snapshot Sync ---
# ==============================================================================

# --- _compact_section_snapshots ---
# @desc_short       : One line if fully synced; per-type lag detail only when behind.
# ================================================================================
function _compact_section_snapshots {
    SUBSECTION "ZFS SNAPSHOT SYNC"

    # Collect only hosts that have snapshot state data on the NFS share
    local hosts=()
    while IFS=' # ' read -r host_name _rest; do
        [[ -f "${PATH_STATE_HOSTS}/${host_name}/zfs-snapshots.json" ]] && hosts+=("${host_name}")
    done < <(get_hosts)

    if (( ${#hosts[@]} < 2 )); then
        INFO "(need at least 2 hosts with snapshot state for comparison)"
        return
    fi

    local host_a="${hosts[0]}"   # leader / reference host
    local host_b="${hosts[1]}"   # backup host

    local file_a="${PATH_STATE_HOSTS}/${host_a}/zfs-snapshots.json"
    local file_b="${PATH_STATE_HOSTS}/${host_b}/zfs-snapshots.json"

    printf '  %b%s%b → %b%s%b   ' \
        "${FONT_BOLD}" "${host_a}" "${FONT_RESET}" \
        "${FONT_BOLD}" "${host_b}" "${FONT_RESET}"

    # Python handles the snapshot set comparison — bash arrays + JSON is unergonomic
    ${CMD_PYTHON} - "${file_a}" "${file_b}" "${host_a}" "${host_b}" <<'PYTHON_EOF'
import json, sys

file_a, file_b, host_a, host_b = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

RESET  = '\033[0m';  DIM = '\033[2m'
RED    = '\033[31m'; GREEN = '\033[32m'

TARGET_POOLS = ('zfs-pool-big', 'zfs-pool-fast', 'zfs-pve')
ORDER        = ('hourly', 'daily', 'weekly', 'monthly', 'yearly')
CANONICAL    = 'zfs-pool-fast/data'   # reference dataset — consistent snap cadence


def get_autosnaps(data):
    """Returns dict: dataset -> set of autosnap snapshot names."""
    result = {}
    for key in data.get('snapshots', {}):
        parts = key.split('@', 1)
        if len(parts) != 2:
            continue
        dataset, snap_name = parts
        if not snap_name.startswith('autosnap_') or \
           not any(dataset.startswith(p) for p in TARGET_POOLS):
            continue
        result.setdefault(dataset, set()).add(snap_name)
    return result


def snap_type(name):
    """Extract frequency suffix from autosnap name (e.g. 'hourly')."""
    return name.rsplit('_', 1)[-1]


def date_range_str(names):
    """Return 'YYYY-MM-DD HH:MM .. YYYY-MM-DD HH:MM' from sorted snap names."""
    def dt(n):
        parts = n.split('_')
        return parts[1] + ' ' + parts[2][:5]
    dates = sorted(dt(n) for n in names)
    return f'{dates[0]} .. {dates[-1]}' if len(dates) > 1 else dates[0]


with open(file_a) as f: data_a = json.load(f)
with open(file_b) as f: data_b = json.load(f)

snaps_a      = get_autosnaps(data_a)
snaps_b      = get_autosnaps(data_b)
canon_a      = snaps_a.get(CANONICAL, set())
canon_b      = snaps_b.get(CANONICAL, set())
common       = canon_a & canon_b
last_common  = sorted(common)[-1].split('_')[1] if common else 'unknown'
missing_b    = sorted(canon_a - canon_b)   # on leader, not yet on backup

if not missing_b:
    print(f'{GREEN}fully synced{RESET}  {DIM}(last: {last_common}){RESET}')
    sys.exit(0)

# Group missing snaps by frequency type for compact display
groups = {}
for name in missing_b:
    groups.setdefault(snap_type(name), []).append(name)

print(f'{RED}sync lag — last common: {last_common}{RESET}')
for t in ORDER:
    if t not in groups:
        continue
    names = groups[t]
    print(f'    {RED}{len(names):2d}x {t:<10}  {date_range_str(names)}{RESET}')

# Snaps purged from leader still present on backup — informational only
missing_a = sorted(canon_b - canon_a)
if missing_a:
    groups_a = {}
    for name in missing_a:
        groups_a.setdefault(snap_type(name), []).append(name)
    print(f'  {DIM}purged from {host_a}, still on {host_b}:{RESET}')
    for t in ORDER:
        if t in groups_a:
            names = groups_a[t]
            print(f'    {DIM}{len(names):2d}x {t:<10}  {date_range_str(names)}{RESET}')
PYTHON_EOF
}

# ==============================================================================
# --- Section: HA Containers ---
# ==============================================================================

# --- _compact_section_containers ---
# @desc_short       : One line listing all HA container IDs; WARN only for stopped ones.
# @notes            : HA_CONTAINER_IDS is populated once in main.sh via _status_fetch_ha_ids.
#                     Container live state is read from lxc-live.txt on the NFS share — no SSH.
# ================================================================================
function _compact_section_containers {
    SUBSECTION "HA CONTAINERS"

    if (( ${#HA_CONTAINER_IDS[@]} == 0 )); then
        WARN "No HA container IDs available — observer has not synced ha_clients to share yet."
        return
    fi

    # Find the first host that has a live container state file on the NFS share
    local leader="" file_lxc=""
    while IFS=' # ' read -r host_name _rest; do
        local candidate="${PATH_STATE_HOSTS}/${host_name}/lxc-live.txt"
        # Use the first host that has the live file — this is the HA leader
        if [[ -f "${candidate}" ]]; then
            leader="${host_name}"
            file_lxc="${candidate}"
            break
        fi
    done < <(get_hosts)

    if [[ -z "${leader}" ]]; then
        WARN "No lxc-live.txt found on any configured host."
        return
    fi

    # Parse lxc-live.txt into an associative array: ID -> "name|status"
    declare -A ct_data
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        local ct_id ct_name ct_status
        ct_id=$(awk '{print $1}' <<< "${line}")              # first field is the container ID
        ct_name=$(awk -F'# | - ' '{print $2}' <<< "${line}") # name is between "# " and " - "
        ct_status=$(awk '{print $NF}' <<< "${line}")          # last field is the status
        ct_data["${ct_id}"]="${ct_name}|${ct_status}"
    done < "${file_lxc}"

    # Classify each HA container as running or stopped
    local running_ids=() stopped_entries=()
    for ha_id in "${HA_CONTAINER_IDS[@]}"; do
        local entry="${ct_data[${ha_id}]}"

        # Container ID not found in live state at all
        if [[ -z "${entry}" ]]; then
            stopped_entries+=("${ha_id}:?:not-in-live")
            continue
        fi

        local ct_name ct_status
        ct_name="${entry%%|*}"    # strip everything from the first | onward
        ct_status="${entry##*|}"  # strip everything up to and including the last |

        if [[ "${ct_status}" == "running" ]]; then
            running_ids+=("${ha_id}")
        else
            stopped_entries+=("${ha_id}:${ct_name}:${ct_status}")
        fi
    done

    local total="${#HA_CONTAINER_IDS[@]}"

    if (( ${#stopped_entries[@]} == 0 )); then
        # All HA containers running — single OK line with all IDs
        OK "all ${total} HA running (${leader}): ${running_ids[*]}"
        return
    fi

    # Show all HA IDs on one compact line, then individual WARNs for stopped ones
    INFO "HA containers (${leader}, ${total}): ${HA_CONTAINER_IDS[*]}"
    for entry in "${stopped_entries[@]}"; do
        IFS=':' read -r ct_id ct_name ct_status <<< "${entry}"
        WARN "${ct_id} (${ct_name}) — ${ct_status}"
    done
}

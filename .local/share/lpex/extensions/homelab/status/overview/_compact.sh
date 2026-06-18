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
    # Use a wider section for the header — timestamp needs the extra space
    #SECTION_WIDTH=100
#	SUBSECTION_WIDTH=150
    SECTION "HOMELAB STATUS   $(date '+%Y-%m-%d  %H:%M:%S')"
    # Reset output globals back to defaults so subsequent sections use normal width

    _compact_section_devices
    _compact_section_zpool
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
    printf '\n %b%-14s  %-14s  %-16s  %-12s  %-4s  %-4s  %-4s  %-3s  %-3s  %-3s  %-3s  %-3s  %s%b\n' \
        "${FONT_DIM}" \
        "DEVICE" "STATUS" "UPDATED" "UPTIME" "MEM" "UPG" "RBT" "W" "CR" "EM" "FL" "OOM" "STORAGE" \
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
        device_name=$(basename "$(dirname "${file_status_json}")")   # derive name from parent dir
        WARN "${device_name} — no status.json"
        return
    fi

    # 1. --- Parse all fields in one jq call to avoid repeated process spawns ---
    local json_out
    json_out=$(${CMD_JQ} -r '
        [
            .hostname,
            .timestamp,
            (.system.uptime_seconds | floor | tostring),
            (.memory.used_percent | tostring),
            (.updates.count_available_upgrades | tostring),
            (.updates.reboot_required | tostring),
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

    # Split the pipe-delimited output into named variables
    IFS='|' read -r hostname ts_raw uptime_s mem_pct upg_count reboot_req \
        j_warn j_crit j_emerg j_fail j_oom \
        zfs_state root_pct state_pct <<< "${json_out}"

    # 2. --- Staleness check: flag data older than the threshold ---
    local age_seconds
    age_seconds=$(_status_calc_age_seconds "${ts_raw}")
    local status_label status_color
    if (( age_seconds > THRESHOLD_STALE_SECONDS )); then
        status_label="STALE $(_status_format_duration "${age_seconds}")"
        status_color="${FONT_RED}"
    else
        status_label="ONLINE"
        status_color="${FONT_GREEN}"
    fi

    # 3. --- Format display columns ---
    local updated_str uptime_str
    updated_str=$(date -d "${ts_raw}" "+%m-%d %H:%M")      # short date-time for the "updated" column
    uptime_str=$(_status_format_duration "${uptime_s}")     # human-readable uptime

    # Memory color: yellow ≥75%, red ≥90%
    local mem_color="${FONT_GREEN}"
    (( mem_pct >= 75 )) && mem_color="${FONT_YELLOW}"
    (( mem_pct >= 90 )) && mem_color="${FONT_RED}"

    # Upgrade count color: yellow if any pending, red if more than 50
    local upg_color="${FONT_RESET}"
    (( upg_count > 0 ))  && upg_color="${FONT_YELLOW}"
    (( upg_count > 50 )) && upg_color="${FONT_RED}"

    # Reboot required flag
    local rbt_label="no" rbt_color="${FONT_RESET}"
    [[ "${reboot_req}" == "true" ]] && rbt_label="YES" && rbt_color="${FONT_RED}"

    # Journal color: yellow for warnings or failed services, red for critical/emergency/oom
    local j_color="${FONT_RESET}"
    (( j_warn > 0 || j_fail > 0 ))                        && j_color="${FONT_YELLOW}"
    (( j_crit > 0 || j_emerg > 0 || j_oom > 0 ))          && j_color="${FONT_RED}"

    # Observers don't report OOM kills — show dash instead of 0
    local j_oom_label="${j_oom}"
    [[ "${device_type}" == "observer" ]] && j_oom_label="—"

    # 4. --- Storage string differs by device type ---
    local storage_str
    if [[ "${device_type}" == "host" ]]; then
        local zfs_color="${FONT_GREEN}" root_color="${FONT_GREEN}"
        # Red if ZFS pool is not in "ok" state
        [[ "${zfs_state}" != "ok" ]] && zfs_color="${FONT_RED}"
        # Color root usage: yellow ≥80%, red ≥90%
        (( root_pct >= 80 )) && root_color="${FONT_YELLOW}"
        (( root_pct >= 90 )) && root_color="${FONT_RED}"
        storage_str="root:${root_color}${root_pct}%${FONT_RESET} zfs:${zfs_color}${zfs_state}${FONT_RESET}"
    else
        local root_color="${FONT_GREEN}"
        (( root_pct >= 80 )) && root_color="${FONT_YELLOW}"
        (( root_pct >= 90 )) && root_color="${FONT_RED}"
        storage_str="root:${root_color}${root_pct}%${FONT_RESET}"
        # Append state partition usage if the observer reports it
        if [[ -n "${state_pct}" ]]; then
            local state_color="${FONT_GREEN}"
            (( state_pct >= 80 )) && state_color="${FONT_YELLOW}"
            (( state_pct >= 90 )) && state_color="${FONT_RED}"
            storage_str+=" state:${state_color}${state_pct}%${FONT_RESET}"
        fi
    fi

    # 5. --- Print the aligned table row ---
    printf ' %b%-14s%b  %b%-14s%b  %-16s  %-12s  %b%-4s%b  %b%-4s%b  %b%-4s%b  %b%-3s  %-3s  %-3s  %-3s  %-3s%b  %b\n' \
        "${FONT_BOLD}"    "${hostname}"    "${FONT_RESET}" \
        "${status_color}" "${status_label}" "${FONT_RESET}" \
        "${updated_str}"  "${uptime_str}" \
        "${mem_color}"    "${mem_pct}%"   "${FONT_RESET}" \
        "${upg_color}"    "${upg_count}"  "${FONT_RESET}" \
        "${rbt_color}"    "${rbt_label}"  "${FONT_RESET}" \
        "${j_color}"      "${j_warn}" "${j_crit}" "${j_emerg}" "${j_fail}" "${j_oom_label}" "${FONT_RESET}" \
        "${storage_str}"
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
# --- Section: ZPool ---
# ==============================================================================

# --- _compact_section_zpool ---
# @desc_short       : One-liner per host if all pools healthy; per-pool detail only on error.
# ================================================================================
function _compact_section_zpool {
    SUBSECTION "ZPOOL"

    while IFS=' # ' read -r host_name _rest; do
        local state_dir="${PATH_STATE_HOSTS}/${host_name}"

        # No state directory — host not yet integrated into monitoring
        if [[ ! -d "${state_dir}" ]]; then
            INFO "${host_name} — not yet integrated"
            continue
        fi

        local file_zpool="${state_dir}/zpool-status.log"

        # State dir exists but zpool log is missing — health script likely failed
        if [[ ! -f "${file_zpool}" ]]; then
            WARN "${host_name} — zpool-status.log missing"
            continue
        fi

        _compact_zpool_host "${host_name}" "${file_zpool}"
    done < <(get_hosts)
}

# --- _compact_zpool_host ---
# @desc_short       : One line if all pools OK; per-pool detail if any issue.
# @usage            : _compact_zpool_host <host_name> <file_zpool>
# @parameter        : $1 | host_name  | Logical host name (e.g. host_1).
# @parameter        : $2 | file_zpool | Absolute path to zpool-status.log.
# ================================================================================
function _compact_zpool_host {
    local host_name="$1"
    local file_zpool="$2"

    # Extract relevant pools — awk emits "pool|state|errors" per matched pool
    local parsed
    parsed=$(awk '
        /^  pool:/ { pool = $2 }
        /^ state:/ { state = $2 }
        /^errors:/ {
            errors = substr($0, index($0, ":") + 2)
            if (pool ~ /^(rpool|zfs-pool-big|zfs-pool-fast|zfs-pve)$/)
                printf "%s|%s|%s\n", pool, state, errors
        }
    ' "${file_zpool}")

    # Determine if all pools are healthy in one pass before deciding output format
    local all_ok=1 pool_count=0
    while IFS='|' read -r _p pool_state pool_errors; do
        (( pool_count++ ))
        # Any non-ONLINE state or non-empty error string breaks the "all OK" path
        if [[ "${pool_state}" != "ONLINE" || "${pool_errors}" != "No known data errors" ]]; then
            all_ok=0
        fi
    done <<< "${parsed}"

    printf '  %-12s  ' "${host_name}"

    if (( all_ok && pool_count > 0 )); then
        OK "all ${pool_count} pools healthy"
        return
    fi

    # One or more pools have issues — print per-pool detail on separate lines
    echo
    while IFS='|' read -r pool_name pool_state pool_errors; do
        printf '    %-22s  ' "${pool_name}"
        if [[ "${pool_state}" == "ONLINE" && "${pool_errors}" == "No known data errors" ]]; then
            OK "ONLINE"
        elif [[ "${pool_state}" == "ONLINE" ]]; then
            WARN "${pool_errors}"
        else
            ERROR "state=${pool_state}  ${pool_errors}"
        fi
    done <<< "${parsed}"
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
        WARN "No HA container IDs available — check SSH connection to leader."
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

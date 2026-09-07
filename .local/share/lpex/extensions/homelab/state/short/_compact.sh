#!/bin/bash
# ==============================================================================
# --- Compact Overview Action ---
# One-pager: device table, ZFS snapshot sync, HA container status.
# All state data is read from the NFS share — no SSH at runtime.
# Sourced by main.sh — do not execute directly.
# ==============================================================================


# ==============================================================================
# --- Column Layout ---
# enter_column prints one fixed-width cell: [color] text [reset] padding.
# c_* wrappers lock in each column's width — change width in exactly one place.
# --vislen must be passed for text that already contains ANSI escape codes so
# the padding calculation uses the visible character count, not the raw length.
# ==============================================================================

# --- enter_column ---
# @desc_short  : Prints a fixed-width column: optional color prefix, text, reset, space padding.
# @parameter   : $1        | width  | Visible column width in characters.
# @parameter   : --color=  | color  | ANSI escape prefix applied before text (optional).
# @parameter   : --vislen= | vislen | Explicit visible text length — required when text
#                                     already contains ANSI codes (optional).
# @parameter   : last arg  | text   | Text string to display.
# ================================================================================
SUBSECTION_WIDTH=75
function enter_column {
    local column_len=$1; shift               # consume the width argument before the loop
    local all="" only_txt=""

    while (( "$#" )); do case "$1" in
        --color=*) all+="${1#--color=}" ;;           # append color escape to the output buffer
        *) all+=" $1"; only_txt+=" $1" ;;            # append text token; plain copy tracks visible length
    esac; shift; done

    local pad_len=$(( column_len - ${#only_txt} ))
    (( pad_len < 0 )) && pad_len=0
    echo -en "${all}${FONT_RESET}$(printf '%*s' "${pad_len}" '')"
}

function c_UPDATE  { enter_column  9 "$@"; }   # UPDATED   — age since last health write
function c_DEVICE  { enter_column 22 "$@"; }   # DEVICE    — hostname + uptime in parens
function c_LASTUPG { enter_column 10 "$@"; }   # LAST UPG  — time since last apt upgrade
function c_UPG     { enter_column  6 "$@"; }   # UPG       — pending packages + reboot marker
function c_MSGS    { enter_column  8 "$@"; }   # MSGS      — journal warnings + service failures
function c_MEM     { enter_column  4 "$@"; }   # MEM       — RAM usage percent
function c_STORE   { enter_column  5 "$@"; }   # STORE     — aggregate storage health label
function c_TYPE    { enter_column  6 "$@"; }   # TYPE      — client type: ct-p | ct-u | vm
function c_DOCK    { enter_column  6 "$@"; }   # DOCK      — docker containers running/total
function c_CLIENT  { enter_column 30 "$@"; }   # CLIENT    — id + name + uptime (wider than DEVICE)
function c_HA      { enter_column  5 "$@"; }   # HA        — HA state: on | off | ovr | —


# ==============================================================================
# --- _action_compact ---
# @desc_short  : Prints the compact one-pager homelab status overview.
# @usage       : _action_compact
# ================================================================================
function _action_compact {
    SECTION "HOMELAB STATUS   $(date '+%Y-%m-%d  %H:%M:%S')"

    _compact_section_devices     # per-device health row table
    _compact_section_clients     # per-client health row table (CTs + VMs)
    _compact_section_snapshots   # ZFS replication lag between hosts
    _compact_section_containers  # HA container running state
    echo
}


# ==============================================================================
# --- Section: Device Table ---
# One compact row per device — hosts first, observers below.
# ==============================================================================

# --- _compact_section_devices ---
# @desc_short  : Prints a compact device status table for all configured hosts and observers.
# ================================================================================
function _compact_section_devices {
    SUBSECTION "DEVICES"

    # Print header row — DIM marks it as metadata, not live content
    c_UPDATE  --color="${FONT_DIM}" "TIME"
    c_DEVICE  --color="${FONT_DIM}" "DEVICE (UP)"
    c_LASTUPG --color="${FONT_DIM}" "DATE_UPG"
    c_UPG     --color="${FONT_DIM}" "UPG"
    c_MSGS    --color="${FONT_DIM}" "MSGS"
    c_MEM     --color="${FONT_DIM}" "MEM"
    c_STORE   --color="${FONT_DIM}" "STORE"
    printf '\n'

    # Iterate all configured hosts; skip unintegrated ones with an info message
    while IFS=' # ' read -r host_name _rest; do
        local state_dir="${PATH_STATE_HOSTS}/${host_name}"
        if [[ ! -d "${state_dir}" ]]; then
            INFO "${host_name} — not yet integrated"   # state dir absent = never initialized
            continue
        fi
        _compact_device_row "${state_dir}/status.json" "host"
    done < <(get_hosts)

    # Iterate all configured observers
    while IFS=' # ' read -r obs_name _rest; do
        local state_dir="${PATH_STATE_OBSERVERS}/${obs_name}"
        if [[ ! -d "${state_dir}" ]]; then
            INFO "${obs_name} — not yet integrated"
            continue
        fi
        _compact_device_row "${state_dir}/status.json" "observer"
    done < <(get_observers)

    # Observer heartbeat age — supplemental line below the table
    [[ -f "${FILE_OBSERVER_HEARTBEAT}" ]] && _compact_heartbeat_line
}


# --- _compact_device_row ---
# @desc_short  : Reads one status.json and prints a single compact device table row.
# @parameter   : $1 | file_status_json | Absolute path to the device's status.json.
# @parameter   : $2 | device_type      | "host" or "observer".
# ================================================================================
function _compact_device_row {
    local file_status_json="$1"
    local device_type="$2"

    # Missing status.json = health script has never run or NFS share not mounted
    if [[ ! -f "${file_status_json}" ]]; then
        local device_name
        device_name=$(basename "$(dirname "${file_status_json}")")   # infer name from parent dir
        WARN "${device_name} — no status.json"
        return
    fi

    # 1. --- Parse JSON -------------------------------------------------------
    # Single jq call to avoid repeated subprocess spawns per field
    local json_out
    json_out=$(${CMD_JQ} -r '
        [
            .hostname,
            .timestamp,
            (.system.uptime_seconds | floor | tostring),
            (.updates.date_last_upgrade // "unknown"),
            (.updates.count_available_upgrades | tostring),
            (.updates.reboot_required // false | tostring),
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

    IFS='|' read -r hostname ts_raw uptime_s date_last_upgrade upg_count reboot_req \
        mem_pct j_warn j_crit j_emerg j_fail j_oom \
        zfs_state root_pct state_pct <<< "${json_out}"   # split into named vars

    # 2. --- UPDATED — age since last health write ----------------------------
    # green ≤24h, yellow >24h, red >3d
    local age_seconds updated_str updated_color="${FONT_GREEN}"
    age_seconds=$(_status_calc_age_seconds "${ts_raw}")
    updated_str=$(_status_format_duration_compact "${age_seconds}")
    (( age_seconds > 86400  )) && updated_color="${FONT_YELLOW}"   # stale after 24h
    (( age_seconds > 259200 )) && updated_color="${FONT_RED}"      # critical after 3d

    # 3. --- DEVICE (UP) — hostname + uptime in parens ------------------------
    # uptime yellow >50d flags hosts likely overdue for a kernel-update reboot
    local uptime_str up_color="${FONT_RESET}"
    uptime_str=$(_status_format_duration_compact "${uptime_s}")
    (( uptime_s > 50*86400 )) && up_color="${FONT_YELLOW}"
    local up_part="(${uptime_str})"

    # 4. --- LAST UPG — time since last apt upgrade ---------------------------
    # unknown = yellow; >50d = yellow; >180d = red
    local last_upg_str last_upg_color="${FONT_RESET}"
    if [[ "${date_last_upgrade}" == "unknown" ]]; then
        last_upg_str="?"; last_upg_color="${FONT_YELLOW}"    # no upgrade record found
    else
        local last_upg_epoch
        last_upg_epoch=$(date -d "${date_last_upgrade}" +%s 2>/dev/null)   # parse date or ISO timestamp to epoch
        if [[ -z "${last_upg_epoch}" ]]; then
            last_upg_str="?"; last_upg_color="${FONT_YELLOW}"   # date format unrecognized
        else
            local last_upg_secs=$(( $(date +%s) - last_upg_epoch ))
            last_upg_str=$(_status_format_duration_compact "${last_upg_secs}")
            (( last_upg_secs > 50*86400  )) && last_upg_color="${FONT_YELLOW}"   # ~7 weeks
            (( last_upg_secs > 180*86400 )) && last_upg_color="${FONT_RED}"      # ~6 months
        fi
    fi

    # 5. --- UPG — available package count + reboot marker ---------------------
    local upg_color="${FONT_RESET}"
    (( upg_count > 0  )) && upg_color="${FONT_YELLOW}"   # any pending packages = yellow
    (( upg_count > 50 )) && upg_color="${FONT_RED}"      # large backlog = red

    # Pending reboot gets a red R! marker appended to the count (e.g. "12 R!")
    local -a upg_args=(--color="${upg_color}" "${upg_count}")
    [[ "${reboot_req}" == "true" ]] && upg_args+=(--color="${FONT_RED}" "R!")

    # 6. --- MSGS — compound: W(CE) + fl + oom --------------------------------
    # W = total journal severity 0–4; CE = critical+emergency subset
    # W yellow; red when CE>0. fl = failed services; oom = OOM kills (hosts only)
    local -a msgs_args=()

    if (( j_warn > 0 )); then
        local w_color="${FONT_YELLOW}"
        (( j_crit + j_emerg > 0 )) && w_color="${FONT_RED}"   # escalate if any critical/emergency
        msgs_args+=(--color="${w_color}" "${j_warn}($(( j_crit + j_emerg )))")  # W(CE) as one token — no space
    fi

    if (( j_fail > 0 )); then
        msgs_args+=(--color="${FONT_YELLOW}" "${j_fail}fl")
    fi

    # OOM kills are host-specific — observers run no workloads that trigger kernel OOM
    if [[ "${device_type}" == "host" ]] && (( j_oom > 0 )); then
        msgs_args+=(--color="${FONT_RED}" "${j_oom}oom")
    fi

    if (( ${#msgs_args[@]} == 0 )); then
        msgs_args=(--color="${FONT_DIM}" "—")   # dim dash = nothing to report
    fi

    # 7. --- MEM — RAM usage percent ------------------------------------------
    local mem_color="${FONT_GREEN}"
    (( mem_pct >= 75 )) && mem_color="${FONT_YELLOW}"
    (( mem_pct >= 90 )) && mem_color="${FONT_RED}"

    # 8. --- STORE — worst-case of: ZFS pool, root partition, state partition --
    local store_label="OK" store_color="${FONT_GREEN}"
    # ZFS pool unhealthy = error (observers report "n/a" — not evaluated)
    if [[ "${device_type}" == "host" && "${zfs_state}" != "ok" && "${zfs_state}" != "n/a" ]]; then
        store_label="ERROR"; store_color="${FONT_RED}"
    fi
    if   (( root_pct >= 90 )); then                                          # root partition critical
        store_label="ERROR"; store_color="${FONT_RED}"
    elif (( root_pct >= 80 )) && [[ "${store_label}" != "ERROR" ]]; then
        store_label="WARN";  store_color="${FONT_YELLOW}"
    fi
    if [[ -n "${state_pct}" && "${state_pct}" != "0" ]]; then               # observer-only state partition
        if   (( state_pct >= 90 )); then
            store_label="ERROR"; store_color="${FONT_RED}"
        elif (( state_pct >= 80 )) && [[ "${store_label}" != "ERROR" ]]; then
            store_label="WARN";  store_color="${FONT_YELLOW}"
        fi
    fi

    # 9. --- Assemble row using column functions -------------------------------
    printf ' '
    c_UPDATE  --color="${updated_color}"  "${updated_str}"
    c_DEVICE  --color="${FONT_BOLD}"      "${hostname}" --color="${up_color}" "${up_part}"
    c_LASTUPG --color="${last_upg_color}" "${last_upg_str}"
    c_UPG     "${upg_args[@]}"
    c_MSGS    "${msgs_args[@]}"
    c_MEM     --color="${mem_color}"      "${mem_pct}%"
    c_STORE   --color="${store_color}"    "${store_label}"
    printf '\n'
}


# --- _compact_heartbeat_line ---
# @desc_short  : Prints the observer heartbeat age below the device table.
# ================================================================================
function _compact_heartbeat_line {
    local hb_json_out hb_node hb_ts hb_age hb_age_str
    hb_json_out=$(${CMD_JQ} -r '[.node, .ts] | join("|")' "${FILE_OBSERVER_HEARTBEAT}")   # single jq call
    IFS='|' read -r hb_node hb_ts <<< "${hb_json_out}"
    hb_age=$(_status_calc_age_seconds "${hb_ts}")
    hb_age_str=$(_status_format_duration "${hb_age}")

    # Select output level based on heartbeat age: ok <10min, warn <1h, error ≥1h
    if   (( hb_age > 3600 )); then ERROR "Heartbeat  ${hb_node} — ${hb_ts}  (${hb_age_str} ago)"
    elif (( hb_age >  600 )); then WARN  "Heartbeat  ${hb_node} — ${hb_ts}  (${hb_age_str} ago)"
    else                            INFO  "Heartbeat  ${hb_node} — ${hb_ts}  (${hb_age_str} ago)"
    fi
}


# ==============================================================================
# --- Section: Client Table ---
# One compact row per client (CT/VM) — read from state/clients/<id>/status.json,
# written daily by get-clients-status.sh on the host. Only running clients have
# a status.json; stopped ones appear in the HA CONTAINERS section instead.
# The HA column combines three share files: the ha_clients boot list, the
# ha_override.json pause flag and the ha_removed.json removal marker.
# ==============================================================================

# --- _compact_section_clients ---
# @desc_short  : Prints a compact client status table for all clients with state on the share.
# ================================================================================
function _compact_section_clients {
    SUBSECTION "CLIENTS"

    # Collect all client state dirs that contain a status.json (skip override-only dirs)
    local -a files_status=()
    local dir_client
    for dir_client in "${PATH_STATE_CLIENTS}"/*/; do
        [[ -f "${dir_client}status.json" ]] && files_status+=("${dir_client}status.json")
    done

    # No client status yet = collector never ran (deploy pending or timer not fired)
    if (( ${#files_status[@]} == 0 )); then
        INFO "no client status on share yet — run trigger-clients-health.sh on the observer"
        return
    fi

    # Print header row — DIM marks it as metadata, not live content
    c_UPDATE  --color="${FONT_DIM}" "TIME"
    c_CLIENT  --color="${FONT_DIM}" "CLIENT (UP)"
    c_TYPE    --color="${FONT_DIM}" "TYPE"
    c_HA      --color="${FONT_DIM}" "HA"
    c_LASTUPG --color="${FONT_DIM}" "DATE_UPG"
    c_UPG     --color="${FONT_DIM}" "UPG"
    c_MSGS    --color="${FONT_DIM}" "MSGS"
    c_MEM     --color="${FONT_DIM}" "MEM"
    c_STORE   --color="${FONT_DIM}" "STORE"
    c_DOCK    --color="${FONT_DIM}" "DOCK"
    printf '\n'

    # One row per client — glob order = ascending PVE ID
    local file_status
    for file_status in "${files_status[@]}"; do
        _compact_client_row "${file_status}"
    done
}


# --- _compact_client_row ---
# @desc_short  : Reads one client status.json and prints a single compact table row.
# @parameter   : $1 | file_status_json | Absolute path to the client's status.json.
# ================================================================================
function _compact_client_row {
    local file_status_json="$1"

    # 1. --- Parse JSON -------------------------------------------------------
    # Single jq call to avoid repeated subprocess spawns per field
    local json_out
    json_out=$(${CMD_JQ} -r '
        [
            (.client_id | tostring),
            (.client_name // .hostname),
            (.client_type // "?"),
            .timestamp,
            (.system.uptime_seconds | floor | tostring),
            (.updates.date_last_upgrade // "unknown"),
            (.updates.count_available_upgrades | tostring),
            (.updates.reboot_required // false | tostring),
            (.memory.used_percent | tostring),
            (.journal.count_warnings_errors_0_4 // 0 | tostring),
            (.journal.count_critical_2 // 0 | tostring),
            (.journal.count_emergency_0_1 // 0 | tostring),
            (.journal.count_failed_services // 0 | tostring),
            (.journal.count_oom_kills // 0 | tostring),
            (.storage.root_usage_percent // 0 | tostring),
            (.docker.containers_running // "" | tostring),
            (.docker.containers_total // "" | tostring)
        ] | join("|")
    ' "${file_status_json}")

    IFS='|' read -r client_id client_name client_type ts_raw uptime_s \
        date_last_upgrade upg_count reboot_req mem_pct \
        j_warn j_crit j_emerg j_fail j_oom \
        root_pct dock_run dock_total <<< "${json_out}"   # split into named vars

    # 2. --- UPDATED — age since last health write ----------------------------
    # green ≤24h, yellow >24h, red >3d (clients are collected daily at 06:10)
    local age_seconds updated_str updated_color="${FONT_GREEN}"
    age_seconds=$(_status_calc_age_seconds "${ts_raw}")
    updated_str=$(_status_format_duration_compact "${age_seconds}")
    (( age_seconds > 86400  )) && updated_color="${FONT_YELLOW}"   # stale after 24h
    (( age_seconds > 259200 )) && updated_color="${FONT_RED}"      # critical after 3d

    # 3. --- CLIENT (UP) — id + name + uptime in parens ------------------------
    local uptime_str up_color="${FONT_RESET}"
    uptime_str=$(_status_format_duration_compact "${uptime_s}")
    (( uptime_s > 50*86400 )) && up_color="${FONT_YELLOW}"   # long uptime = pending reboot likely
    local up_part="(${uptime_str})"

    # 4. --- TYPE — short client type label ------------------------------------
    # ct_privileged → ct-p | ct_unprivileged → ct-u | vm → vm
    local type_str="?"
    case "${client_type}" in
        ct_privileged)   type_str="ct-p" ;;
        ct_unprivileged) type_str="ct-u" ;;
        vm)              type_str="vm"   ;;
    esac

    # 5. --- HA — high-availability state of this container --------------------
    # Override wins over list membership: the CT is listed but its HA is paused.
    # A removal marker outranks "never managed" — it means someone took it out.
    local ha_str="—" ha_color="${FONT_DIM}"
    if [[ -f "${PATH_STATE_CLIENTS}/${client_id}/ha_override.json" ]]; then
        ha_str="ovr"; ha_color="${FONT_YELLOW}"     # HA paused by an override file
    elif [[ " ${HA_CONTAINER_IDS[*]} " == *" ${client_id} "* ]]; then
        ha_str="on";  ha_color="${FONT_GREEN}"      # in the boot list, watcher restarts it
    elif [[ -f "${PATH_STATE_CLIENTS}/${client_id}/ha_removed.json" ]]; then
        ha_str="off"; ha_color="${FONT_YELLOW}"     # deliberately removed, running unprotected
    fi

    # 6. --- LAST UPG — time since last package upgrade ------------------------
    # unknown = yellow; >50d = yellow; >180d = red (same thresholds as devices)
    local last_upg_str last_upg_color="${FONT_RESET}"
    if [[ "${date_last_upgrade}" == "unknown" ]]; then
        last_upg_str="?"; last_upg_color="${FONT_YELLOW}"    # no upgrade record found
    else
        local last_upg_epoch
        last_upg_epoch=$(date -d "${date_last_upgrade}" +%s 2>/dev/null)   # parse date or ISO timestamp to epoch
        if [[ -z "${last_upg_epoch}" ]]; then
            last_upg_str="?"; last_upg_color="${FONT_YELLOW}"   # date format unrecognized
        else
            local last_upg_secs=$(( $(date +%s) - last_upg_epoch ))
            last_upg_str=$(_status_format_duration_compact "${last_upg_secs}")
            (( last_upg_secs > 50*86400  )) && last_upg_color="${FONT_YELLOW}"   # ~7 weeks
            (( last_upg_secs > 180*86400 )) && last_upg_color="${FONT_RED}"      # ~6 months
        fi
    fi

    # 7. --- UPG — available package count + reboot marker ---------------------
    local upg_color="${FONT_RESET}"
    (( upg_count > 0  )) && upg_color="${FONT_YELLOW}"   # any pending packages = yellow
    (( upg_count > 50 )) && upg_color="${FONT_RED}"      # large backlog = red

    # Pending reboot gets a red R! marker appended to the count (e.g. "12 R!")
    local -a upg_args=(--color="${upg_color}" "${upg_count}")
    [[ "${reboot_req}" == "true" ]] && upg_args+=(--color="${FONT_RED}" "R!")

    # 8. --- MSGS — compound: W(CE) + fl + oom ---------------------------------
    # Same semantics as the device table; OOM shown for clients too (docker workloads)
    local -a msgs_args=()

    if (( j_warn > 0 )); then
        local w_color="${FONT_YELLOW}"
        (( j_crit + j_emerg > 0 )) && w_color="${FONT_RED}"   # escalate if any critical/emergency
        msgs_args+=(--color="${w_color}" "${j_warn}($(( j_crit + j_emerg )))")  # W(CE) as one token — no space
    fi

    if (( j_fail > 0 )); then
        msgs_args+=(--color="${FONT_YELLOW}" "${j_fail}fl")
    fi

    if (( j_oom > 0 )); then
        msgs_args+=(--color="${FONT_RED}" "${j_oom}oom")
    fi

    if (( ${#msgs_args[@]} == 0 )); then
        msgs_args=(--color="${FONT_DIM}" "—")   # dim dash = nothing to report
    fi

    # 9. --- MEM — RAM usage percent -------------------------------------------
    local mem_color="${FONT_GREEN}"
    (( mem_pct >= 75 )) && mem_color="${FONT_YELLOW}"
    (( mem_pct >= 90 )) && mem_color="${FONT_RED}"

    # 10. --- STORE — root filesystem usage (clients have no ZFS pools) ---------
    local store_label="OK" store_color="${FONT_GREEN}"
    if   (( root_pct >= 90 )); then
        store_label="ERROR"; store_color="${FONT_RED}"
    elif (( root_pct >= 80 )); then
        store_label="WARN";  store_color="${FONT_YELLOW}"
    fi

    # 11. --- DOCK — docker containers running/total ----------------------------
    # No docker section in JSON = client without docker → dim dash
    local -a dock_args=(--color="${FONT_DIM}" "—")
    if [[ -n "${dock_total}" ]]; then
        local dock_color="${FONT_GREEN}"
        # Fewer running than defined = at least one stack container is down
        (( dock_run < dock_total )) && dock_color="${FONT_RED}"
        dock_args=(--color="${dock_color}" "${dock_run}/${dock_total}")
    fi

    # 12. --- Assemble row using column functions --------------------------------
    printf ' '
    c_UPDATE  --color="${updated_color}"  "${updated_str}"
    c_CLIENT  --color="${FONT_BOLD}"      "${client_id} ${client_name}" --color="${up_color}" "${up_part}"
    c_TYPE    "${type_str}"
    c_HA      --color="${ha_color}"       "${ha_str}"
    c_LASTUPG --color="${last_upg_color}" "${last_upg_str}"
    c_UPG     "${upg_args[@]}"
    c_MSGS    "${msgs_args[@]}"
    c_MEM     --color="${mem_color}"      "${mem_pct}%"
    c_STORE   --color="${store_color}"    "${store_label}"
    c_DOCK    "${dock_args[@]}"
    printf '\n'
}


# ==============================================================================
# --- Section: ZFS Snapshot Sync ---
# Compares the canonical autosnap set between the two configured hosts.
# Pure bash + jq: set difference via comm, grouping via associative arrays.
# ==============================================================================

# --- _compact_section_snapshots ---
# @desc_short  : One sync-status line when current; per-frequency lag detail when behind.
# @notes       : zfs-pool-fast/data used as canonical reference dataset (consistent cadence).
#                comm requires sorted input — jq output is piped through sort.
#                No Python dependency.
# ================================================================================
function _compact_section_snapshots {
    SUBSECTION "ZFS SNAPSHOT SYNC"

    # Collect only hosts that have a snapshot state file on the NFS share
    local hosts=()
    while IFS=' # ' read -r host_name _rest; do
        [[ -f "${PATH_STATE_HOSTS}/${host_name}/zfs-snapshots.json" ]] && hosts+=("${host_name}")
    done < <(get_hosts)

    if (( ${#hosts[@]} < 2 )); then
        INFO "(need at least 2 hosts with snapshot state for comparison)"
        return
    fi

    local host_a="${hosts[0]}"   # leader / primary (reference for expected snap set)
    local host_b="${hosts[1]}"   # backup / replica (compared against leader)
    local file_a="${PATH_STATE_HOSTS}/${host_a}/zfs-snapshots.json"
    local file_b="${PATH_STATE_HOSTS}/${host_b}/zfs-snapshots.json"
    local canon_ds="zfs-pool-fast/data"   # reference dataset with the most consistent snap cadence

    printf '  %b%s%b → %b%s%b   ' \
        "${FONT_BOLD}" "${host_a}" "${FONT_RESET}" \
        "${FONT_BOLD}" "${host_b}" "${FONT_RESET}"

    # Extract sorted autosnap names for the canonical dataset from each host
    local -a snaps_a snaps_b
    mapfile -t snaps_a < <(${CMD_JQ} -r --arg ds "${canon_ds}" \
        '.snapshots | to_entries[]
         | select(.key | startswith($ds + "@autosnap_"))
         | .key | split("@")[1]' "${file_a}" 2>/dev/null | sort)

    mapfile -t snaps_b < <(${CMD_JQ} -r --arg ds "${canon_ds}" \
        '.snapshots | to_entries[]
         | select(.key | startswith($ds + "@autosnap_"))
         | .key | split("@")[1]' "${file_b}" 2>/dev/null | sort)

    if (( ${#snaps_a[@]} == 0 )); then
        printf '%b(no autosnap snapshots found on %s)%b\n' "${FONT_DIM}" "${host_a}" "${FONT_RESET}"
        return
    fi

    # Find snapshots present on host_a but missing on host_b (the replication lag)
    local -a missing_b
    if (( ${#snaps_b[@]} == 0 )); then
        missing_b=("${snaps_a[@]}")   # backup has nothing = all snapshots missing
    else
        mapfile -t missing_b < <(comm -23 \
            <(printf '%s\n' "${snaps_a[@]}") \
            <(printf '%s\n' "${snaps_b[@]}"))   # comm -23: lines only in file1 = missing on b
    fi

    if (( ${#missing_b[@]} == 0 )); then
        # Fully in sync — show the latest snapshot date for confirmation
        local last_snap="${snaps_a[-1]}"
        local last_snap_date="${last_snap#autosnap_}"; last_snap_date="${last_snap_date%%_*}"   # extract YYYY-MM-DD
        printf '%bfully synced%b  %b(last: %s)%b\n' \
            "${FONT_GREEN}" "${FONT_RESET}" "${FONT_DIM}" "${last_snap_date}" "${FONT_RESET}"
        return
    fi

    # Lag detected — find last common snapshot by scanning host_a ascending, keeping last match
    local last_common="" s
    declare -A _set_b
    for s in "${snaps_b[@]}"; do _set_b["$s"]=1; done          # build O(1) lookup set from host_b snaps
    for s in "${snaps_a[@]}"; do                                 # walk host_a; last hit = most-recent common
        [[ -n "${_set_b[$s]}" ]] && last_common="$s"
    done
    local lc_date="${last_common#autosnap_}"; lc_date="${lc_date%%_*}"   # strip prefix and time, keep date

    printf '%bsync lag — last common: %s%b\n' "${FONT_RED}" "${lc_date}" "${FONT_RESET}"
    _compact_snap_group "${FONT_RED}" "${missing_b[@]}"   # group missing snaps by frequency + date range

    # Snapshots purged from leader but still on backup — informational only
    local -a purged
    mapfile -t purged < <(comm -13 \
        <(printf '%s\n' "${snaps_a[@]}") \
        <(printf '%s\n' "${snaps_b[@]}"))   # comm -13: lines only in file2 = extra on b (purged from a)

    if (( ${#purged[@]} > 0 )); then
        printf '  %bpurged from %s, still on %s:%b\n' \
            "${FONT_DIM}" "${host_a}" "${host_b}" "${FONT_RESET}"
        _compact_snap_group "${FONT_DIM}" "${purged[@]}"
    fi
}


# --- _compact_snap_group ---
# @desc_short  : Groups autosnap names by frequency type; prints count + date range per type.
# @parameter   : $1      | color | ANSI color applied to all output lines.
# @parameter   : $2..$n  | snaps | Snapshot names in autosnap_YYYY-MM-DD_HH:MM:SS_FREQ format.
# @notes       : Output order: hourly → daily → weekly → monthly → yearly.
#                ISO 8601 datetime strings compare lexicographically = chronologically.
# ================================================================================
function _compact_snap_group {
    local color="$1"; shift
    local -a order=("hourly" "daily" "weekly" "monthly" "yearly")
    declare -A cnt first last   # per-frequency: entry count, earliest datetime, latest datetime

    for snap in "$@"; do
        # Decompose autosnap_YYYY-MM-DD_HH:MM:SS_FREQ into sortable display components
        local snap_type="${snap##*_}"                                  # frequency = last underscore-field
        local snap_body="${snap#autosnap_}"                            # strip "autosnap_" prefix
        local snap_date="${snap_body%%_*}"                             # YYYY-MM-DD = first underscore-field
        local snap_time="${snap_body#*_}"; snap_time="${snap_time%%_*}"; snap_time="${snap_time:0:5}"  # HH:MM
        local snap_dt="${snap_date} ${snap_time}"                      # "YYYY-MM-DD HH:MM" — ISO-sortable

        (( cnt[$snap_type]++ ))
        # Track earliest and latest datetime per type for range output
        [[ -z "${first[$snap_type]}" || "$snap_dt" < "${first[$snap_type]}" ]] && first[$snap_type]="$snap_dt"
        [[ -z "${last[$snap_type]}"  || "$snap_dt" > "${last[$snap_type]}"  ]] && last[$snap_type]="$snap_dt"
    done

    for t in "${order[@]}"; do
        [[ -z "${cnt[$t]}" ]] && continue   # skip frequency types absent from this group
        if [[ "${first[$t]}" == "${last[$t]}" ]]; then
            printf '    %b%2dx %-10s  %s%b\n' \
                "${color}" "${cnt[$t]}" "$t" "${first[$t]}" "${FONT_RESET}"
        else
            printf '    %b%2dx %-10s  %s .. %s%b\n' \
                "${color}" "${cnt[$t]}" "$t" "${first[$t]}" "${last[$t]}" "${FONT_RESET}"
        fi
    done
}


# ==============================================================================
# --- Section: HA Containers ---
# ==============================================================================

# --- _compact_section_containers ---
# @desc_short  : One-line all-OK summary, or individual WARNs for stopped HA containers.
# @notes       : HA_CONTAINER_IDS is populated once in main.sh via _status_fetch_ha_ids.
#                Container live state is read from lxc-live.txt on the NFS share — no SSH.
# ================================================================================
function _compact_section_containers {
    SUBSECTION "HA CONTAINERS"

    if (( ${#HA_CONTAINER_IDS[@]} == 0 )); then
        WARN "No HA container IDs available — observer has not synced ha_clients to share yet."
        return
    fi

    # Find the first host that has a live container state file — that host is the HA leader
    local leader="" file_lxc=""
    while IFS=' # ' read -r host_name _rest; do
        local candidate="${PATH_STATE_HOSTS}/${host_name}/lxc-live.txt"
        if [[ -f "${candidate}" ]]; then
            leader="${host_name}"    # first host with live state = current HA leader
            file_lxc="${candidate}"
            break
        fi
    done < <(get_hosts)

    if [[ -z "${leader}" ]]; then
        WARN "No lxc-live.txt found on any configured host."
        return
    fi

    # Parse lxc-live.txt into lookup table: ct_id → "name|status"
    # Line format: "ID   # name - status"
	local ct_live=$(cat "${file_lxc}" | sed -E 's/ # /;/; s/ - /;/')  # replace " # " and " - " with semicolons for easier parsing
	local ct_states=""

	for line in ${ct_live}; do
		[[ -z "${line}" ]] && continue
		# if container id is not in HA_CONTAINER_IDS, skip it
		[[ " ${HA_CONTAINER_IDS[*]} " == *" ${line%%;*} "* ]] || continue
		[[ $line == *";running" ]] && ct_states+="$FONT_GREEN${line%%;*} ${FONT_RESET}"  # color ID 
		[[ $line == *";stopped" ]] && ct_states+="$FONT_RED${line%%;*} ${FONT_RESET}"  # color ID
	done
		echo -e "${ct_states}"

    # Deliberately removed containers keep a line of their own — they are running but
    # unprotected, and without this they would silently disappear from this section
    if (( ${#HA_REMOVED_IDS[@]} > 0 )); then
        local removed_line="" removed_id

        # Build one space-separated "<id> (<date>)" token per removed container
        for removed_id in "${HA_REMOVED_IDS[@]}"; do
            removed_line+="${removed_id} (${HA_REMOVED_DATE[${removed_id}]})  "
        done
        printf '%b\n' "${FONT_YELLOW}not HA:  ${removed_line}${FONT_RESET}"
    fi

}

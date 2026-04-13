#!/bin/bash
# ==============================================================================
# @meta_module      : server observer status
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Displays the live HA cluster state of an Observer Pi.
# @desc_detailed    : SSHes into the target Observer and reads the local state files
# @desc_detailed    : (leader role, ZFS sync flag) and active systemd timer states.
# @desc_detailed    : Additionally parses the observer heartbeat JSON from the locally
# @desc_detailed    : mounted NFS pool to show the last heartbeat age.
#
# @arg_values       : --node | Target Observer (pi1 or pi2). Defaults to pi1.
#
# @exit_codes       : 0 | Status successfully fetched and displayed
# @exit_codes       : 1 | Observer unreachable or required config variable missing
#
# @notes            : Reads ~/db/flags/ on the observer for HA state.
# @notes            : Reads $PATH_POOL_FAST/monitoring/state/observer_heartbeat.json
# @notes            : locally for heartbeat age (no extra SSH required).
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_OBSERVER"

    if (( ARG_ALL )); then
        # [LOGIC] Check both Observers in sequence so the full HA picture is visible
        # in one call — useful to compare leader state, heartbeat age, and timer status.
        for node in pi1 pi2; do
            show_observer_status "$node"
        done
        return 0
    fi

    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    [[ -z "$node" ]] && node="pi1"
    show_observer_status "$node"
}

# ==============================================================================
# --- Helper: show_observer_status ---
# @desc_short       : Fetches and displays the HA state for a single Observer.
# @parameter        : $1 | node | Observer name (pi1 or pi2)
# ================================================================================
function show_observer_status() {
    local node="$1"
    local ip=$(get_observer_ip "$node")
    output --section "Observer Status: $node ($ip)"

    # ==========================================================================
    # --- Feature: Remote State Introspection ---
    # Read all HA-relevant state files and timer states in a single SSH session.
    # ==========================================================================
    output --info "Fetching live state from $node..."
    local state_raw
    state_raw=$(ssh -o ConnectTimeout=3 "$USER_OBSERVER@$ip" '
        echo "OBS_LEADER_LABEL"
        cat ~/db/flags/observer_leader 2>/dev/null || echo "(not set)"
        echo "---"
        echo "ZFS_SYNC_LABEL"
        cat ~/db/flags/allow_zfs_sync 2>/dev/null || echo "(not set)"
        echo "---"
        echo "HEARTBEAT_SVC_LABEL"
        systemctl is-active obs-heartbeat.timer 2>/dev/null || echo "unknown"
        echo "---"
        echo "UPTIME_LABEL"
        uptime
        echo "---"
        echo "TIMERS_LABEL"
        systemctl list-timers --no-pager 2>/dev/null | awk "NR>1 && /obs-|job-/ {print}"
        echo "---"
    ' 2>/dev/null)

    if [[ -z "$state_raw" ]]; then
        output --error "Observer '$node' is unreachable or SSH failed."
        return 1
    fi

    # Parse and display the multi-block response from the observer
    local current_label=""
    while IFS= read -r line; do
        case "$line" in
            OBS_LEADER_LABEL)  output --warn "\n  HA Role (observer_leader):" ; current_label="leader"   ;;
            ZFS_SYNC_LABEL)    output --warn "\n  ZFS Sync Flag (allow_zfs_sync):" ; current_label="zfs" ;;
            HEARTBEAT_SVC_LABEL) output --warn "\n  Heartbeat Timer:" ; current_label="hb"               ;;
            UPTIME_LABEL)      output --warn "\n  System Uptime:" ; current_label="uptime"               ;;
            TIMERS_LABEL)      output --warn "\n  Active HA Timers:" ; current_label="timers"            ;;
            ---)               current_label="" ;;
            "")                ;; # Skip empty lines
            *)
                # [LOGIC] Add contextual colour: ZFS sync flag 0 is a warning state
                # (failover just happened, sync blocked). Everything else is info.
                if [[ "$current_label" == "zfs" && "$line" == "0" ]]; then
                    output --warn "  $line  ← sync blocked after failover"
                elif [[ "$current_label" == "hb" && "$line" != "active" ]]; then
                    output --error "  $line"
                else
                    output --ok "  $line"
                fi
                ;;
        esac
    done <<< "$state_raw"

    # ==========================================================================
    # --- Feature: Local Heartbeat Age Check ---
    # Read the heartbeat JSON from the locally mounted NFS pool — no extra SSH
    # needed, and gives the real "time since last heartbeat" in seconds.
    # ==========================================================================
    if [[ -n "$PATH_POOL_FAST" ]]; then
        local file_heartbeat="$PATH_POOL_FAST/monitoring/state/observer_heartbeat.json"

        output --warn "\n  NFS Heartbeat ($file_heartbeat):"

        if [[ ! -f "$file_heartbeat" ]]; then
            output --error "  File not found — NFS not mounted or heartbeat never written."
            return 0
        fi

        # [LOGIC] Parse with grep + parameter expansion to avoid a jq dependency.
        # The heartbeat JSON uses simple "key": "value" lines written by obs-heartbeat.sh.
        local hb_node
        local hb_ts
        local hb_role
        hb_node=$(grep -oP '"observer_id"\s*:\s*"\K[^"]+' "$file_heartbeat" 2>/dev/null)
        hb_ts=$(grep -oP '"timestamp"\s*:\s*"\K[^"]+' "$file_heartbeat" 2>/dev/null)
        hb_role=$(grep -oP '"role"\s*:\s*"\K[^"]+' "$file_heartbeat" 2>/dev/null)

        if [[ -z "$hb_ts" ]]; then
            output --error "  Could not parse heartbeat timestamp."
            return 0
        fi

        # [LOGIC] Calculate the age of the heartbeat in seconds. date -d parses ISO 8601
        # timestamps on Linux (GNU coreutils). If parsing fails, age stays at -1.
        local hb_epoch
        hb_epoch=$(date -d "$hb_ts" +%s 2>/dev/null) || hb_epoch=-1
        local now_epoch
        now_epoch=$(date +%s)
        local age_sec=$(( now_epoch - hb_epoch ))

        output --ok "  Written by : $hb_node ($hb_role)"
        output --ok "  Timestamp  : $hb_ts"

        # [LOGIC] Flag the age in yellow if > 90s (1.5x the 60s interval → likely stale),
        # and red if > 360s (6 minutes → peer-check threshold would have triggered).
        if (( hb_epoch == -1 )); then
            output --error "  Age        : (parse error)"
        elif (( age_sec > 360 )); then
            output --error "  Age        : ${age_sec}s  ← STALE — failover should have triggered"
        elif (( age_sec > 90 )); then
            output --warn "  Age        : ${age_sec}s  ← delayed"
        else
            output --ok "  Age        : ${age_sec}s"
        fi
    fi
}

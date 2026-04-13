#!/bin/bash
# ==============================================================================
# @meta_module      : server host status
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Displays the health status of one or all Proxmox hosts.
# @desc_detailed    : By default reads the pre-computed JSON from the NFS share
# @desc_detailed    : (Ebene 1), giving instant results with richer data (pending
# @desc_detailed    : APT upgrades, journal errors, OOM kills, ZFS state).
# @desc_detailed    : Use --live for a real-time SSH query when NFS data is stale.
# @desc_detailed    : Use --all to check pve101, pve102 and pve103 in one call.
#
# @arg_values       : --node | Target Proxmox node (pve101, pve102, pve103)
# @arg_flags        : --all  | Check all three PVE nodes sequentially
# @arg_flags        : --live | Force a live SSH query instead of reading from NFS
#
# @exit_codes       : 0 | Status displayed successfully
# @exit_codes       : 1 | Missing config variable or all nodes unreachable
#
# @notes            : NFS path: $PATH_POOL_FAST/monitoring/state/<node>_health.json
# @notes            : The JSON is written by get-host-status.sh triggered by the Observer.
# ==============================================================================

# ==============================================================================
# --- Helper: show_node_status ---
# @desc_short       : Fetches and displays status for a single node.
# @parameter        : $1 | node | The Proxmox node name (e.g. pve101)
# ================================================================================
function show_node_status() {
    local node="$1"
    local node_upper="${node^^}"
    local ip_var="IP_${node_upper}"
    local ip="${!ip_var}"

    output --section "Host Health: $node"

    if [[ -z "$ip" ]]; then
        output --error "IP not found for $node. Define $ip_var in config.conf."
        return 1
    fi

    # ==========================================================================
    # --- Feature: NFS Cache Read (default) ---
    # Read the pre-computed JSON that the Observer wrote to Ebene 1.
    # Falls back to live SSH automatically if the file doesn't exist yet.
    # ==========================================================================
    if (( ! ARG_LIVE )) && [[ -n "$PATH_POOL_FAST" ]]; then
        local file_health="$PATH_POOL_FAST/monitoring/state/${node}_health.json"

        if [[ -f "$file_health" ]]; then
            # --- Parse JSON fields using grep + parameter expansion (no jq needed) ---
            local ts hostname uptime_s load reboot_req
            local upgrades last_upgrade
            local warn_err emerg crit failed_svc oom
            local zfs_state root_usage

            ts=$(grep -oP '"timestamp"\s*:\s*"\K[^"]+' "$file_health")
            hostname=$(grep -oP '"hostname"\s*:\s*"\K[^"]+' "$file_health")
            uptime_s=$(grep -oP '"uptime_seconds"\s*:\s*\K[0-9.]+' "$file_health")
            load=$(grep -oP '"load_1m"\s*:\s*\K[0-9.]+' "$file_health")
            reboot_req=$(grep -oP '"reboot_required"\s*:\s*\K(true|false)' "$file_health")
            upgrades=$(grep -oP '"count_available_upgrades"\s*:\s*\K[0-9]+' "$file_health")
            last_upgrade=$(grep -oP '"date_last_upgrade"\s*:\s*"\K[^"]+' "$file_health")
            warn_err=$(grep -oP '"count_warnings_errors_0_4"\s*:\s*\K[0-9]+' "$file_health")
            emerg=$(grep -oP '"count_emergency_0_1"\s*:\s*\K[0-9]+' "$file_health")
            crit=$(grep -oP '"count_critical_2"\s*:\s*\K[0-9]+' "$file_health")
            failed_svc=$(grep -oP '"count_failed_services"\s*:\s*\K[0-9]+' "$file_health")
            oom=$(grep -oP '"count_oom_kills"\s*:\s*\K[0-9]+' "$file_health")
            zfs_state=$(grep -oP '"zfs_state"\s*:\s*"\K[^"]+' "$file_health")
            root_usage=$(grep -oP '"root_usage_percent"\s*:\s*\K[0-9]+' "$file_health")

            # [LOGIC] Convert uptime seconds to a human-readable h/m string
            local uptime_h=$(( ${uptime_s%.*} / 3600 ))
            local uptime_m=$(( (${uptime_s%.*} % 3600) / 60 ))

            output --warn "\n  System"
            output --ok   "  Hostname : $hostname"
            output --ok   "  Snapshot : $ts"
            output --ok   "  Uptime   : ${uptime_h}h ${uptime_m}m"
            output --ok   "  Load     : $load"
            output --ok   "  Root     : ${root_usage}% used"

            output --warn "\n  Updates"
            # [LOGIC] Highlight pending upgrades in yellow if > 0; red if reboot needed
            if (( upgrades > 0 )); then
                output --warn "  Pending  : $upgrades packages (last upgrade: $last_upgrade)"
            else
                output --ok  "  Pending  : 0 packages (last upgrade: $last_upgrade)"
            fi
            [[ "$reboot_req" == "true" ]] && output --error "  Reboot   : REQUIRED" || output --ok "  Reboot   : not required"

            output --warn "\n  Journal & Services"
            # [LOGIC] Highlight journal anomalies — anything > 0 for emerg/crit/oom is flagged red
            (( emerg   > 0 )) && output --error "  Emergency: $emerg" || output --ok "  Emergency: 0"
            (( crit    > 0 )) && output --error "  Critical : $crit"  || output --ok "  Critical : 0"
            (( warn_err > 0 )) && output --warn "  Warnings : $warn_err" || output --ok "  Warnings : 0"
            (( failed_svc > 0 )) && output --error "  Failed   : $failed_svc service(s)" || output --ok "  Failed   : 0 services"
            (( oom > 0 )) && output --error "  OOM Kills: $oom" || output --ok "  OOM Kills: 0"

            output --warn "\n  Storage"
            [[ "$zfs_state" == "ok" ]] && output --ok "  ZFS      : ONLINE" || output --error "  ZFS      : $zfs_state"

            output --blank ""
            return 0
        fi

        output --warn "No cached status found for $node. Falling back to live SSH..."
        output --info "(Run 'lpex server host status --node $node --live' to suppress this)"
    fi

    # ==========================================================================
    # --- Feature: Live SSH Query ---
    # Triggered by --live or when no NFS cache file exists.
    # ==========================================================================
    enforce_config_var "USER_PVE"
    output --info "Live query: $node ($ip)..."

    local script='
        echo "=LOAD="; uptime
        echo "=MEM="; free -m | awk "NR==2{printf \"RAM: %s MB used / %s MB total (%.1f%%)\n\",\$3,\$2,\$3*100/\$2}"
        echo "=ZFS="; command -v zpool >/dev/null && zpool list -o name,health || echo "ZFS not available"
        echo "=APT="; apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l | awk "{print \$1 \" packages upgradable\"}"
    '

    local result
    result=$(ssh -o ConnectTimeout=3 "$USER_PVE@$ip" "$script" 2>/dev/null)

    if [[ -z "$result" ]]; then
        output --error "Node $node is unreachable or offline."
        return 1
    fi

    echo "$result" | while IFS= read -r line; do
        case "$line" in
            =LOAD=) output --warn "\n  Load"     ;;
            =MEM=)  output --warn "\n  Memory"   ;;
            =ZFS=)  output --warn "\n  ZFS Pools" ;;
            =APT=)  output --warn "\n  Updates"  ;;
            "")     ;;
            *)      output --ok "  $line"         ;;
        esac
    done
    output --blank ""
}

# ==============================================================================
# --- Main Entry Point ---
# ==============================================================================
function extension_start() {

    if (( ARG_ALL )); then
        # [LOGIC] Loop over all known Proxmox nodes and display status for each.
        # The loop uses fixed names; nodes that are offline will show an error per-node
        # rather than aborting the entire run.
        for node in pve101 pve102 pve103; do
            show_node_status "$node"
        done
        return 0
    fi

    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    if [[ -z "$node" ]]; then
        output --error "Proxmox node required (--node) or use --all."
        return 1
    fi

    show_node_status "$node"
}

#!/bin/bash
# ==============================================================================
# @meta_module      : server host control
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Manages physical power states of Proxmox nodes.
# @desc_detailed    : Wake-On-LAN for --start, ACPI shutdown/reboot via SSH for
# @desc_detailed    : --stop and --restart. Requires 'wol' package for WOL.
#
# @arg_values       : --node    | Target Proxmox node (pve101, pve102, pve103)
# @arg_flags        : --start   | Wake the node via Wake-On-LAN (WOL)
# @arg_flags        : --stop    | Send ACPI graceful shutdown via SSH
# @arg_flags        : --restart | Send ACPI reboot via SSH
#
# @exit_codes       : 0 | Signal dispatched
# @exit_codes       : 1 | Missing node, missing 'wol' binary, or IP resolution failure
# ==============================================================================

function extension_start() {
    # --- 1. Infrastructure Validation ---
    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    if [[ -z "$node" ]]; then
        output --error "Hardware Node Name required (--node)."
        return 1
    fi

    local node_upper="${node^^}"
    
    # ==========================================================================
    # --- Feature: Hardware Power Dispatcher ---
    # Routes power states to WOL or SSH-ACPI controllers.
    # ==========================================================================
    if (( ARG_START )); then
        output --section "Hardware Wakeup: $node"
        
        # --- Feature: Wake-On-LAN (WOL) ---
        local mac_var="MAC_$node_upper"
        enforce_config_var "$mac_var"
        local mac="${!mac_var}"
        
        # Check if the 'wol' command (wakeonlan package) is installed locally
        if ! command -v wol >/dev/null 2>&1; then
            output --error "The 'wol' command is not installed on this system."
            output --warn "Please install it (e.g. 'sudo pacman -S wakeonlan' or 'sudo apt install wakeonlan')."
            return 1
        fi
        
        output --info "Sending Magic Packet to $mac..."
        if lx cmd --run "wol $mac" --quiet; then
            output --ok "Wake-On-LAN signal successfully dispatched."
        else
            output --error "Failed to send WOL signal."
        fi
        
    elif (( ARG_STOP )) || (( ARG_RESTART )); then
        # Both Stop and Restart require an active SSH connection to send ACPI signals
        enforce_config_var "USER_PVE"
        
        local ip_var="IP_$node_upper"
        enforce_config_var "$ip_var"
        local ip="${!ip_var}"
        
        if (( ARG_STOP )); then
            output --section "Graceful Shutdown: $node"
            if lx cmd --run "ssh -t $USER_PVE@$ip 'shutdown -h now'" --log --log-tags "host,stop"; then
                output --ok "Shutdown signal successfully dispatched to $ip."
            fi
        elif (( ARG_RESTART )); then
            output --section "Graceful Reboot: $node"
            if lx cmd --run "ssh -t $USER_PVE@$ip 'shutdown -r now'" --log --log-tags "host,restart"; then
                output --ok "Reboot signal successfully dispatched to $ip."
            fi
        fi
    else
        output --error "No action specified. Use --start, --stop, or --restart."
    fi
}

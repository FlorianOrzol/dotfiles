#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server host control
# Description: Orchestrates the physical power states of the Proxmox bare-metal 
# servers via Wake-On-LAN and ACPI SSH commands.
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

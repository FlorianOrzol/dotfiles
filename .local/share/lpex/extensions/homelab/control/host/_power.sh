#!/bin/bash
# ==============================================================================
# @meta_name        : _power.sh
# @desc_short       : Power action implementations for hosts.
#                     Sourced by control/host/main.sh.
# ==============================================================================

# --- action_power ---
# @desc_short  : Executes a power action on a host.
# @usage       : action_power <device> <action>
# @parameter   : $1 | device | Host name (e.g. host_1)
# @parameter   : $2 | action | start | restart | shutdown
# @notes       : start  — WOL via host-wake.sh on observer (host may be offline)
#                restart — direct SSH reboot (host must be reachable)
#                shutdown — graceful halt via host-shutdown.sh on observer
# ==============================================================================
function action_power {
    local device="$1" action="$2"
    local ip

    INFO "Executing [${action}] on host '${device}'..."

    case "$action" in
        start)
            execute_on_device "$OBSERVER_PRIMARY" "/opt/homelab/bin/hosts/host-wake.sh ${device}"  # WOL packet sent from observer
            ;;
        shutdown)
            ip=$(get_device_ip "$device") || return 1                                                # resolve IP for shutdown script
            execute_on_device "$OBSERVER_PRIMARY" "/opt/homelab/bin/hosts/host-shutdown.sh ${ip}"   # graceful halt via observer
            ;;
        restart)
            execute_on_device "$device" "shutdown -r now"  # direct SSH reboot
            ;;
    esac
}

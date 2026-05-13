#!/bin/bash
# ==============================================================================
# @meta_name        : _power.sh
# @desc_short       : Power action implementations (start / stop / restart).
#                     Sourced by control/main.sh.
# ==============================================================================

# --- action_power ---
# @desc_short  : Dispatches a power action to the appropriate device-type handler.
# @usage       : action_power <type> <device> <action>
# @parameter   : $1 | type   | Device type: host | observer | container | vm
# @parameter   : $2 | device | Device name or ID
# @parameter   : $3 | action | start | stop | restart
# ==============================================================================
function action_power {
    local type="$1" device="$2" action="$3"

    INFO "Executing [${action}] on ${type} '${device}'..."

    case "$type" in
        observer)  _power_observer  "$device" "$action" ;;
        host)      _power_host      "$device" "$action" ;;
        container) _power_container "$device" "$action" ;;
        vm)        _power_vm        "$device" "$action" ;;
    esac
}

# --- _power_observer ---
# @desc_short  : Power actions for observers (start not supported remotely).
# ==============================================================================
function _power_observer {
    local device="$1" action="$2"

    case "$action" in
        start)
            ERROR "Cannot remotely start an observer — use physical power or WOL manually."
            return 1
            ;;
        stop)
            execute_on_device "$device" "sudo shutdown -h now"
            ;;
        restart)
            execute_on_device "$device" "sudo reboot"
            ;;
    esac
}

# --- _power_host ---
# @desc_short  : Power actions for hosts — start/stop routed via primary observer.
# @notes       : Start uses WOL via host-wake.sh on observer; stop uses host-shutdown.sh.
# ==============================================================================
function _power_host {
    local device="$1" action="$2"
    local ip

    case "$action" in
        start)
            # WOL triggered via primary observer — host-wake.sh resolves MAC internally
            execute_on_device "$OBSERVER_PRIMARY" "/opt/homelab/bin/hosts/host-wake.sh ${device}"
            ;;
        stop)
            # Graceful shutdown via primary observer using host IP
            ip=$(get_device_ip "$device") || return 1
            execute_on_device "$OBSERVER_PRIMARY" "/opt/homelab/bin/hosts/host-shutdown.sh ${ip}"
            ;;
        restart)
            execute_on_device "$device" "shutdown -r now"
            ;;
    esac
}

# --- _power_container ---
# @desc_short  : Power actions for containers via pct on the running host.
# ==============================================================================
function _power_container {
    local device="$1" action="$2"
    local host pct_action="$action"

    # pct uses 'reboot' instead of 'restart'
    [[ "$action" == "restart" ]] && pct_action="reboot"

    host=$(find_container_host "$device") || return 1
    execute_on_device "$host" "pct ${pct_action} ${device}"
}

# --- _power_vm ---
# @desc_short  : Power actions for VMs via qm on the running host.
# ==============================================================================
function _power_vm {
    local device="$1" action="$2"
    local host qm_action="$action"

    # qm uses 'reboot' instead of 'restart'
    [[ "$action" == "restart" ]] && qm_action="reboot"

    host=$(find_vm_host "$device") || return 1
    execute_on_device "$host" "qm ${qm_action} ${device}"
}

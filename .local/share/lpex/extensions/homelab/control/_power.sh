#!/bin/bash
# ==============================================================================
# @meta_name        : control/_power.sh
# @desc_short       : Power action implementation (start / stop / restart).
# ==============================================================================

# ==============================================================================
# --- _action_power ---
# @desc_short   : Executes a power action on the target device via SSH.
# @parameter    : $1 | type   | Device type (observer, host, container, vm)
# @parameter    : $2 | id     | Device ID
# @parameter    : $3 | action | start | stop | restart
# ==============================================================================
function _action_power {
    local type="$1" id="$2" action="$3"
    local name
    name=$(_device_name "$type" "$id" 2>/dev/null || echo "${type}_${id}")

    INFO "Executing [${action}] on [${type}] ${name}..."

    case "$type" in

        observer)
            # Observer power actions run via direct SSH
            case "$action" in
                start)   ERROR "Cannot remotely start an observer (use physical power or WOL)."; return 1 ;;
                stop)    _run_on_observer "$id" "sudo shutdown -h now" ;;
                restart) _run_on_observer "$id" "sudo reboot" ;;
            esac
            ;;

        host)
            case "$action" in
                start)
                    # WOL via the leader observer — uses host-wake.sh
                    local obs_id
                    obs_id=$(_leader_observer_id)
                    _run_on_observer "$obs_id" \
                        "/opt/homelab/bin/hosts/host-wake.sh $(_device_name "host" "$id")"
                    ;;
                stop)
                    _run_on_observer "$(_leader_observer_id)" \
                        "/opt/homelab/bin/hosts/host-shutdown.sh $(_device_ip "host" "$id")"
                    ;;
                restart)
                    _run_on_host "$id" "shutdown -r now"
                    ;;
            esac
            ;;

        container)
            # Container actions via pct on the host that runs the container
            local host_id
            host_id=$(_host_for_container "$id") || return 1
            local pct_action="$action"
            # Map "restart" to "reboot" for pct compatibility
            [[ "$action" == "restart" ]] && pct_action="reboot"
            _run_on_host "$host_id" "pct ${pct_action} ${id}"
            ;;

        vm)
            # VM actions via qm on the host that runs the VM
            local host_id
            host_id=$(_host_for_container "$id") || return 1
            local qm_action="$action"
            # Map "start"/"stop"/"restart" to qm equivalents
            [[ "$action" == "restart" ]] && qm_action="reboot"
            _run_on_host "$host_id" "qm ${qm_action} ${id}"
            ;;

        *)
            ERROR "Unknown device type: ${type}"
            return 1
            ;;
    esac

    local exit_code=$?
    # Report result based on the SSH/pct/qm exit code
    if (( exit_code == 0 )); then
        OK "[${action}] executed on [${type}] ${name}."
    else
        ERROR "[${action}] failed on [${type}] ${name} (exit ${exit_code})."
        return 1
    fi
}

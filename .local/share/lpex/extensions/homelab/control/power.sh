#!/bin/bash
# ==============================================================================
# @meta_name        : control/power.sh
# @desc_short       : Power action implementation (start / stop / restart).
#                     Sourced by control/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_power ---
# @desc_short   : Executes a power action on the target device via SSH.
# @parameter    : $1 | type   | Device type (observer, host, container, vm)
# @parameter    : $2 | id     | Device ID
# @parameter    : $3 | action | start | stop | restart
# ==============================================================================
function action_power {
    local type="$1" id="$2" action="$3"
    local name
    name=$(device_name "$type" "$id" 2>/dev/null || echo "${type}_${id}")

    INFO "Executing [${action}] on [${type}] ${name}..."

    case "$type" in

        observer)
            case "$action" in
                start)   ERROR "Cannot remotely start an observer (use physical power or WOL)."; return 1 ;;
                stop)    run_on_observer "$id" "sudo shutdown -h now" ;;
                restart) run_on_observer "$id" "sudo reboot" ;;
            esac
            ;;

        host)
            case "$action" in
                start)
                    # WOL via the leader observer — uses host-wake.sh
                    local obs_id
                    obs_id=$(leader_observer_id)
                    run_on_observer "$obs_id" \
                        "/opt/homelab/bin/hosts/host-wake.sh $(device_name "host" "$id")"
                    ;;
                stop)
                    run_on_observer "$(leader_observer_id)" \
                        "/opt/homelab/bin/hosts/host-shutdown.sh $(device_ip "host" "$id")"
                    ;;
                restart)
                    run_on_host "$id" "shutdown -r now"
                    ;;
            esac
            ;;

        container)
            # Container actions via pct on the host that runs the container
            local host_id
            host_id=$(host_for_container "$id") || return 1
            local pct_action="$action"
            [[ "$action" == "restart" ]] && pct_action="reboot"
            run_on_host "$host_id" "pct ${pct_action} ${id}"
            ;;

        vm)
            # VM actions via qm on the host that runs the VM
            local host_id
            host_id=$(host_for_container "$id") || return 1
            local qm_action="$action"
            [[ "$action" == "restart" ]] && qm_action="reboot"
            run_on_host "$host_id" "qm ${qm_action} ${id}"
            ;;

        *)
            ERROR "Unknown device type: ${type}"
            return 1
            ;;
    esac

    local exit_code=$?
    if (( exit_code == 0 )); then
        OK "[${action}] executed on [${type}] ${name}."
    else
        ERROR "[${action}] failed on [${type}] ${name} (exit ${exit_code})."
        return 1
    fi
}

#!/bin/bash
# ==============================================================================
# @meta_name        : control/ha_override.sh
# @desc_short       : HA override and maintenance flag implementation.
#                     Sourced by control/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_ha_override ---
# @desc_short   : Sets or clears maintenance state for a device.
# @parameter    : $1 | type | Device type (observer, host, container, vm)
# @parameter    : $2 | id   | Device ID
# ==============================================================================
function action_ha_override {
    local type="$1" id="$2"
    local name
    name=$(device_name "$type" "$id" 2>/dev/null || echo "${type}_${id}")

    # --- --activate: remove maintenance state and restore normal operation ---
    if [[ -n "$ARG_ACTIVATE" ]]; then
        case "$type" in
            observer)
                run_on_observer "$id" \
                    "rm -rf /opt/homelab/state/flags/unit_skip/* && \
                     sudo systemctl start obs-boot-state-restore.service"
                ;;
            host)
                local host_name
                host_name=$(device_name "host" "$id")
                rm -f "${PATH_SHARE_STATE}/hosts/${host_name}/maintenance.json"
                ;;
            container|vm)
                rm -f "${PATH_SHARE_STATE}/${type}_${id}/ha_override.json"
                ;;
        esac
        OK "[${type}] ${name}: maintenance cleared — restored to normal operation."
        return 0
    fi

    # --- --maintenance: put device into maintenance state ---
    if [[ -n "$ARG_MAINTENANCE" ]]; then
        case "$type" in
            observer)
                # Set unit-skip flags for all HA timers — observer leaves production
                local timers=("obs-heartbeat.timer" "obs-ha-clients-watch.timer" "job-backup-nightly.timer")
                local json='{"reason":"maintenance","set_by":"lpex"}'
                local cmds=""
                for timer in "${timers[@]}"; do
                    cmds+="mkdir -p /opt/homelab/state/flags/unit_skip && \
                        echo '${json}' > /opt/homelab/state/flags/unit_skip/${timer}; \
                        sudo systemctl stop ${timer}; "
                done
                run_on_observer "$id" "$cmds"
                INFO "Observer ${name} is now in maintenance — observer_2 will promote automatically."
                ;;
            host)
                local host_name maint_dir maint_json
                host_name=$(device_name "host" "$id")
                maint_dir="${PATH_SHARE_STATE}/hosts/${host_name}"
                maint_json="${maint_dir}/maintenance.json"
                mkdir -p "$maint_dir"
                echo '{"reason":"maintenance","set_by":"lpex"}' > "$maint_json"
                INFO "Host ${name} flagged as maintenance — observer will skip job scheduling."
                ;;
            container|vm)
                local override_dir override_file
                override_dir="${PATH_SHARE_STATE}/${type}_${id}"
                override_file="${override_dir}/ha_override.json"
                mkdir -p "$override_dir"
                echo '{"mode":"maintenance","set_by":"lpex"}' > "$override_file"
                INFO "[${type}] ${name} HA paused — container remains running but HA will not restart it."
                ;;
        esac
        OK "[${type}] ${name}: maintenance mode active. Use --activate to restore."
        return 0
    fi
}

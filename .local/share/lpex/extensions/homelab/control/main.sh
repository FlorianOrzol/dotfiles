#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Main execution logic for the control submodule.
# ==============================================================================

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Entry point called by the LPEX framework.
# @usage            : Automatically invoked after arguments.sh is processed.
# ==============================================================================
function extension_start {
    # 1. --- Validate Device Selection ---------------
    _validate_device || return 1
    local device_type="$_DEVICE_TYPE"
    local device_id="$_DEVICE_ID"

    # 2. --- Validate Action Selection ---------------
    local power_count=0
    [[ -n "$ARG_START" ]]   && (( power_count++ ))
    [[ -n "$ARG_STOP" ]]    && (( power_count++ ))
    [[ -n "$ARG_RESTART" ]] && (( power_count++ ))

    local ha_active=0
    [[ -n "$ARG_MODE" || -n "$ARG_CLEAR" ]] && ha_active=1

    if (( power_count == 0 && !ha_active )); then
        ERROR "No action specified. Provide --start, --stop, --restart, --mode, or --clear."
        return 1
    fi

    if (( power_count > 1 )); then
        ERROR "Only one power action allowed at a time (--start, --stop, or --restart)."
        return 1
    fi

    if [[ -n "$ARG_MODE" && -n "$ARG_CLEAR" ]]; then
        ERROR "--mode and --clear are mutually exclusive."
        return 1
    fi

    # 3. --- Action Routing ---------------
    # ------ HA-Override is applied first, then the power action.

    if (( ha_active )); then
        _action_ha_override "$device_type" "$device_id" || return 1
    fi

    if [[ -n "$ARG_START" ]];   then _action_power "$device_type" "$device_id" "start";   fi
    if [[ -n "$ARG_STOP" ]];    then _action_power "$device_type" "$device_id" "stop";    fi
    if [[ -n "$ARG_RESTART" ]]; then _action_power "$device_type" "$device_id" "restart"; fi
}

# ==============================================================================
# --- function _action_ha_override ---
# @desc_short       : Writes or clears the HA-Override flag file on the NFS share.
# @parameter        : $1 | type | Device type (host, observer, container, vm).
# @parameter        : $2 | id   | Device ID.
# ==============================================================================
function _action_ha_override {
    local type="$1"
    local id="$2"
    local state_dir="$MOUNT_POOL_FAST/data/homelab_data/state"
    local override_file="$state_dir/${type}_${id}/ha_override.json"

    if [[ -n "$ARG_CLEAR" ]]; then
        INFO "Clearing HA-Override for [$type] $id..."
        # Placeholder: ssh observer "rm -f '$override_file'"
        OK "HA-Override cleared. HA is active again."
        return 0
    fi

    local expires_at="${ARG_TIME:-never}"
    local override_json
    override_json=$(printf '{"mode":"%s","expires_at":"%s","set_by":"lpex"}' "$ARG_MODE" "$expires_at")

    INFO "Setting HA-Override for [$type] $id..."
    INFO "Mode    : $ARG_MODE"
    INFO "Duration: ${ARG_TIME:-manual}"

    # Placeholder: ssh observer "mkdir -p '$(dirname "$override_file")' && echo '$override_json' > '$override_file'"

    OK "HA-Override set (mode: $ARG_MODE)."
}

# ==============================================================================
# --- function _action_power ---
# @desc_short       : Routes and executes a power action on the target device.
# @parameter        : $1 | type   | Device type (host, observer, container, vm).
# @parameter        : $2 | id     | Device ID.
# @parameter        : $3 | action | Power action (start, stop, restart).
# ==============================================================================
function _action_power {
    local type="$1"
    local id="$2"
    local action="$3"

    INFO "Executing [$action] on [$type] $id..."

    # Placeholder: route via observer SSH → host → pct / qm / shutdown
    # case "$type" in
    #   container) ssh observer "ssh host_X 'pct $action $id'" ;;
    #   vm)        ssh observer "ssh host_X 'qm $action $id'" ;;
    #   host)      ssh observer "ssh $id 'shutdown ...'" ;;
    #   observer)  ssh "$id" 'shutdown ...' ;;
    # esac

    OK "[$action] executed on [$type] $id."
}

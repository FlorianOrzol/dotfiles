#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Main execution logic for the setup container submodule.
# ==============================================================================

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Entry point called by the LPEX framework.
# ==============================================================================
function extension_start {
    # 1. --- Validate ID ---------------
    if [[ -z "$ARG_ID" ]]; then
        ERROR "No container ID specified."
        return 1
    fi

    # 2. --- Validate Action ---------------
    local action_count=0
    [[ -n "$ARG_CREATE" ]]      && (( action_count++ ))
    [[ -n "$ARG_DELETE" ]]      && (( action_count++ ))
    [[ -n "$ARG_EDIT" ]]        && (( action_count++ ))
    [[ -n "$ARG_SHOW_CONFIG" ]] && (( action_count++ ))

    if (( action_count == 0 )); then
        ERROR "No action specified. Provide --create, --delete, --edit, or --show-config."
        return 1
    fi

    if (( action_count > 1 )); then
        ERROR "Only one action allowed at a time."
        return 1
    fi

    # 3. --- Action Routing ---------------
    if [[ -n "$ARG_CREATE" ]];      then _action_create;      fi
    if [[ -n "$ARG_DELETE" ]];      then _action_delete;      fi
    if [[ -n "$ARG_EDIT" ]];        then _action_edit;        fi
    if [[ -n "$ARG_SHOW_CONFIG" ]]; then _action_show_config; fi
}

# ==============================================================================
# --- function _action_create ---
# @desc_short       : Creates a new LXC container on the target host.
# ==============================================================================
function _action_create {
    # Required fields
    local missing=()
    [[ -z "$ARG_HOST" ]]     && missing+=("--host")
    [[ -z "$ARG_TEMPLATE" ]] && missing+=("--template")
    [[ -z "$ARG_RAM" ]]      && missing+=("--ram")
    [[ -z "$ARG_DISK" ]]     && missing+=("--disk")

    if (( ${#missing[@]} > 0 )); then
        ERROR "Missing required options: ${missing[*]}"
        return 1
    fi

    INFO "Creating container $ARG_ID on host $ARG_HOST..."

    # Build pct create argument list from provided options
    local pct_args=()
    pct_args+=( "$ARG_ID" )
    pct_args+=( --hostname  "${ARG_NAME:-ct-$ARG_ID}" )
    pct_args+=( --memory    "$ARG_RAM" )
    pct_args+=( --swap      "${ARG_SWAP:-$ARG_RAM}" )
    pct_args+=( --cores     "${ARG_CPU:-2}" )
    pct_args+=( --cpulimit  "${ARG_MAX_CPU:-100}" )
    pct_args+=( --rootfs    "${ARG_STORAGE:-fastpool}:${ARG_DISK}" )
    pct_args+=( --net0      "name=eth0,bridge=${ARG_BRIDGE:-vmbr0}${ARG_IP_ADDRESS:+,ip=$ARG_IP_ADDRESS}${ARG_GATEWAY:+,gw=$ARG_GATEWAY}" )
    pct_args+=( --start     0 )

    (( ARG_PRIVILEGED ))           && pct_args+=( --unprivileged 0 ) || pct_args+=( --unprivileged 1 )
    [[ -n "$ARG_SSH" ]]            && pct_args+=( --ssh "$ARG_SSH" )
    [[ -n "$ARG_AUTOSTART" ]]      && pct_args+=( --onboot "$([[ $ARG_AUTOSTART == on ]] && echo 1 || echo 0)" )

    # Bind mounts (--multi → ARG_BINDS array)
    local mp_index=0
    for bind in "${ARG_BINDS[@]:-}"; do
        [[ -n "$bind" ]] && pct_args+=( "--mp${mp_index}" "$bind" ) && (( mp_index++ ))
    done

    # Features (--multi → ARG_FEATURES array)
    if (( ${#ARG_FEATURES[@]:-0} > 0 )); then
        local features_str
        features_str=$(IFS=,; echo "${ARG_FEATURES[*]}")
        pct_args+=( --features "$features_str" )
    fi

    # Placeholder: ssh observer "ssh host_X 'pct create ${pct_args[*]}'"
    INFO "pct create ${pct_args[*]}"

    # HA enrollment after creation
    if [[ "$ARG_HA" == "yes" ]]; then
        INFO "Adding ct-$ARG_ID to HA..."
        # Placeholder: ssh observer "ssh host_X 'ha-manager add ct:$ARG_ID'"
    fi

    # Backup job assignment
    if [[ -n "$ARG_AUTO_BACKUP" ]]; then
        INFO "Assigning backup job $ARG_AUTO_BACKUP to ct-$ARG_ID..."
        # Placeholder: assign backup job via pvesh
    fi

    OK "Container ct-$ARG_ID created."
}

# ==============================================================================
# --- function _action_delete ---
# @desc_short       : Deletes an LXC container on the target host.
# ==============================================================================
function _action_delete {
    WARN "This will permanently delete container ct-$ARG_ID."

    # Placeholder: ssh observer "ssh host_X 'pct stop $ARG_ID; pct destroy $ARG_ID'"

    OK "Container ct-$ARG_ID deleted."
}

# ==============================================================================
# --- function _action_edit ---
# @desc_short       : Edits the configuration of an existing LXC container.
#                     Disk size can only be increased. ID cannot be changed.
# ==============================================================================
function _action_edit {
    INFO "Editing container ct-$ARG_ID..."

    local pct_args=()

    [[ -n "$ARG_NAME" ]]     && pct_args+=( --hostname  "$ARG_NAME" )
    [[ -n "$ARG_RAM" ]]      && pct_args+=( --memory    "$ARG_RAM" )
    [[ -n "$ARG_SWAP" ]]     && pct_args+=( --swap      "$ARG_SWAP" )
    [[ -n "$ARG_CPU" ]]      && pct_args+=( --cores     "$ARG_CPU" )
    [[ -n "$ARG_MAX_CPU" ]]  && pct_args+=( --cpulimit  "$ARG_MAX_CPU" )
    [[ -n "$ARG_BRIDGE" ]]   && pct_args+=( --net0      "name=eth0,bridge=$ARG_BRIDGE" )
    [[ -n "$ARG_SSH" ]]      && pct_args+=( --ssh       "$ARG_SSH" )
    [[ -n "$ARG_AUTOSTART" ]] && pct_args+=( --onboot "$([[ $ARG_AUTOSTART == on ]] && echo 1 || echo 0)" )

    # Disk resize (only increase — validated at execution time by pct)
    if [[ -n "$ARG_DISK" ]]; then
        INFO "Resizing rootfs to ${ARG_DISK}G..."
        # Placeholder: ssh observer "ssh host_X 'pct resize $ARG_ID rootfs ${ARG_DISK}G'"
    fi

    # Features
    if (( ${#ARG_FEATURES[@]:-0} > 0 )); then
        local features_str
        features_str=$(IFS=,; echo "${ARG_FEATURES[*]}")
        pct_args+=( --features "$features_str" )
    fi

    if (( ${#pct_args[@]} > 0 )); then
        # Placeholder: ssh observer "ssh host_X 'pct set $ARG_ID ${pct_args[*]}'"
        INFO "pct set $ARG_ID ${pct_args[*]}"
    else
        WARN "No options provided — nothing to edit."
        return 1
    fi

    OK "Container ct-$ARG_ID updated."
}

# ==============================================================================
# --- function _action_show_config ---
# @desc_short       : Displays the current configuration of an LXC container.
# ==============================================================================
function _action_show_config {
    INFO "Fetching config for container ct-$ARG_ID..."

    # Placeholder: ssh observer "ssh host_X 'pct config $ARG_ID'"

    OK "Config displayed."
}

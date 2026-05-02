#!/bin/bash
# ==============================================================================
# @meta_name        : setup/container/_edit.sh
# @desc_short       : Container-Konfiguration ändern und anzeigen.
#                     Sourced by setup/container/main.sh.
# ==============================================================================

# ==============================================================================
# --- _action_edit ---
# @desc_short   : Edits the configuration of an existing LXC container.
#                 Disk size can only be increased. ID cannot be changed.
# ==============================================================================
function _action_edit {
    # Find the host that currently runs this container
    local host_id
    host_id=$(_host_for_container "$ARG_ID") || return 1

    local pct_args=()

    # Collect provided options into the pct set argument list
    [[ -n "$ARG_NAME" ]]     && pct_args+=( --hostname  "$ARG_NAME" )
    [[ -n "$ARG_RAM" ]]      && pct_args+=( --memory    "$ARG_RAM" )
    [[ -n "$ARG_SWAP" ]]     && pct_args+=( --swap      "$ARG_SWAP" )
    [[ -n "$ARG_CPU" ]]      && pct_args+=( --cores     "$ARG_CPU" )
    [[ -n "$ARG_MAX_CPU" ]]  && pct_args+=( --cpulimit  "$ARG_MAX_CPU" )
    [[ -n "$ARG_BRIDGE" ]]   && pct_args+=( --net0      "name=eth0,bridge=$ARG_BRIDGE" )
    [[ -n "$ARG_SSH" ]]      && pct_args+=( --ssh       "$ARG_SSH" )
    [[ -n "$ARG_AUTOSTART" ]] && pct_args+=( --onboot "$([[ $ARG_AUTOSTART == on ]] && echo 1 || echo 0)" )

    # Features via --multi array
    if (( ${#ARG_FEATURES[@]:-0} > 0 )); then
        local features_str
        features_str=$(IFS=,; echo "${ARG_FEATURES[*]}")
        pct_args+=( --features "$features_str" )
    fi

    # Abort if no options were provided — nothing to do
    if (( ${#pct_args[@]} == 0 )) && [[ -z "${ARG_DISK:-}" ]]; then
        WARN "No options provided — nothing to edit."
        return 1
    fi

    INFO "Editing container ct-${ARG_ID} on host ${host_id}..."

    # Apply configuration changes if any pct set args were built
    if (( ${#pct_args[@]} > 0 )); then
        _run_on_host "$host_id" "pct set ${ARG_ID} ${pct_args[*]}" || return 1
    fi

    # Resize rootfs separately — pct resize only allows increasing disk size
    if [[ -n "$ARG_DISK" ]]; then
        INFO "Resizing rootfs to ${ARG_DISK}G..."
        _run_on_host "$host_id" "pct resize ${ARG_ID} rootfs ${ARG_DISK}G" || return 1
    fi

    OK "Container ct-${ARG_ID} updated."
}

# ==============================================================================
# --- _action_show_config ---
# @desc_short   : Displays the current pct configuration of an LXC container.
# ==============================================================================
function _action_show_config {
    local host_id
    host_id=$(_host_for_container "$ARG_ID") || return 1

    INFO "Fetching config for container ct-${ARG_ID}..."
    _run_on_host "$host_id" "pct config ${ARG_ID}"
}

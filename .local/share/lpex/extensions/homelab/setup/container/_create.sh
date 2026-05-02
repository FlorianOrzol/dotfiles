#!/bin/bash
# ==============================================================================
# @meta_name        : setup/container/_create.sh
# @desc_short       : Container-Erstellung via pct auf dem Ziel-Host.
#                     Sourced by setup/container/main.sh.
# ==============================================================================

# ==============================================================================
# --- _action_create ---
# @desc_short   : Creates a new LXC container on the target host via pct.
# ==============================================================================
function _action_create {
    # Validate required options before building the pct command
    local missing=()
    [[ -z "$ARG_HOST" ]]     && missing+=("--host")
    [[ -z "$ARG_TEMPLATE" ]] && missing+=("--template")
    [[ -z "$ARG_RAM" ]]      && missing+=("--ram")
    [[ -z "$ARG_DISK" ]]     && missing+=("--disk")

    if (( ${#missing[@]} > 0 )); then
        ERROR "Missing required options: ${missing[*]}"
        return 1
    fi

    # Build the pct create argument list from all provided options
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

    # Set privileged/unprivileged mode
    (( ARG_PRIVILEGED )) && pct_args+=( --unprivileged 0 ) || pct_args+=( --unprivileged 1 )
    [[ -n "$ARG_SSH" ]]       && pct_args+=( --ssh "$ARG_SSH" )
    [[ -n "$ARG_AUTOSTART" ]] && pct_args+=( --onboot "$([[ $ARG_AUTOSTART == on ]] && echo 1 || echo 0)" )

    # Add bind mounts from --multi array
    local mp_index=0
    for bind in "${ARG_BINDS[@]:-}"; do
        [[ -n "$bind" ]] && pct_args+=( "--mp${mp_index}" "$bind" ) && (( mp_index++ ))
    done

    # Add features from --multi array
    if (( ${#ARG_FEATURES[@]:-0} > 0 )); then
        local features_str
        features_str=$(IFS=,; echo "${ARG_FEATURES[*]}")
        pct_args+=( --features "$features_str" )
    fi

    INFO "Creating container ct-${ARG_ID} on host ${ARG_HOST}..."
    _run_on_host "$ARG_HOST" "pct create ${pct_args[*]}" || return 1

    # Add to HA manager after successful creation if requested
    if [[ "$ARG_HA" == "yes" ]]; then
        INFO "Adding ct-${ARG_ID} to HA..."
        _run_on_host "$ARG_HOST" "ha-manager add ct:${ARG_ID}" || true
    fi

    # Assign to a backup job if requested
    if [[ -n "$ARG_AUTO_BACKUP" ]]; then
        INFO "Assigning backup job ${ARG_AUTO_BACKUP} to ct-${ARG_ID}..."
        _run_on_host "$ARG_HOST" \
            "pvesh set /cluster/backup/${ARG_AUTO_BACKUP} --vmid ${ARG_ID}" || true
    fi

    OK "Container ct-${ARG_ID} created."
}

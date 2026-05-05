#!/bin/bash
# ==============================================================================
# @meta_name        : setup/container/create.sh
# @desc_short       : Container-Erstellung via pct. Sourced by setup/container/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_create ---
# @desc_short   : Creates a new LXC container on the target host via pct.
# ==============================================================================
function action_create {
    # Collect names of required options that were not provided
    local missing=()
    [[ -z "$ARG_HOST" ]]     && missing+=("--host")
    [[ -z "$ARG_TEMPLATE" ]] && missing+=("--template")
    [[ -z "$ARG_RAM" ]]      && missing+=("--ram")
    [[ -z "$ARG_DISK" ]]     && missing+=("--disk")

    # Abort early if any required option is missing
    if (( ${#missing[@]} > 0 )); then
        ERROR "Missing required options: ${missing[*]}"
        return 1
    fi

    # Build the pct argument array from provided options
    local pct_args=()
    # Positional VMID must be first
    pct_args+=( "$ARG_ID" )
    pct_args+=( --hostname  "${ARG_NAME:-ct-$ARG_ID}" )
    pct_args+=( --memory    "$ARG_RAM" )
    # Default swap to RAM size if not explicitly set
    pct_args+=( --swap      "${ARG_SWAP:-$ARG_RAM}" )
    # Default to 2 CPU cores if not specified
    pct_args+=( --cores     "${ARG_CPU:-2}" )
    # Default CPU limit to 100% if not specified
    pct_args+=( --cpulimit  "${ARG_MAX_CPU:-100}" )
    # Combine storage pool and disk size into rootfs spec
    pct_args+=( --rootfs    "${ARG_STORAGE:-fastpool}:${ARG_DISK}" )
    # Build net0 string with optional IP and gateway
    pct_args+=( --net0      "name=eth0,bridge=${ARG_BRIDGE:-vmbr0}${ARG_IP_ADDRESS:+,ip=$ARG_IP_ADDRESS}${ARG_GATEWAY:+,gw=$ARG_GATEWAY}" )
    # Do not autostart the container after creation
    pct_args+=( --start     0 )
    # Unprivileged by default; --privileged flag flips it to 0
    (( ARG_PRIVILEGED )) && pct_args+=( --unprivileged 0 ) || pct_args+=( --unprivileged 1 )
    [[ -n "$ARG_SSH" ]]       && pct_args+=( --ssh    "$ARG_SSH" )
    [[ -n "$ARG_AUTOSTART" ]] && pct_args+=( --onboot "$([[ $ARG_AUTOSTART == on ]] && echo 1 || echo 0)" )

    # Add bind mounts from --multi array
    local mp_index=0
    for bind in "${ARG_BINDS[@]:-}"; do
        # Skip empty entries that may appear when ARG_BINDS is unset
        [[ -n "$bind" ]] && pct_args+=( "--mp${mp_index}" "$bind" ) && (( mp_index++ ))
    done

    # Add features from --multi array
    if (( ${#ARG_FEATURES[@]:-0} > 0 )); then
        local features_str
        # Join feature names into a comma-separated string as required by pct
        features_str=$(IFS=,; echo "${ARG_FEATURES[*]}")
        pct_args+=( --features "$features_str" )
    fi

    INFO "Creating container ct-${ARG_ID} on host ${ARG_HOST}..."
    # Execute pct create on the target host via SSH tunnel through observer
    run_on_host "$ARG_HOST" "pct create ${pct_args[*]}" || return 1

    # Register with HA manager if requested
    if [[ "$ARG_HA" == "yes" ]]; then
        INFO "Adding ct-${ARG_ID} to HA..."
        run_on_host "$ARG_HOST" "ha-manager add ct:${ARG_ID}" || true
    fi

    # Assign container to a backup job if a job ID was provided
    if [[ -n "$ARG_AUTO_BACKUP" ]]; then
        INFO "Assigning backup job ${ARG_AUTO_BACKUP} to ct-${ARG_ID}..."
        run_on_host "$ARG_HOST" "pvesh set /cluster/backup/${ARG_AUTO_BACKUP} --vmid ${ARG_ID}" || true
    fi

    OK "Container ct-${ARG_ID} created."
}

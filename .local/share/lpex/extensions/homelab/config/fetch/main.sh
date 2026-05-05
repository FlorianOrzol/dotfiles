#!/bin/bash
# ==============================================================================
# @meta_name        : config/fetch/main.sh
# @desc_short       : Recover homelab.conf from observer_1 and import into DB.
# ==============================================================================

source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/extension_global.sh"

function extension_start {
    local obs_ip
    obs_ip=$(device_ip "observer" "1") || return 1   # resolve observer_1 IP; abort if unavailable
    local mirror_conf="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"

    INFO "Fetching homelab.conf from observer_1 (${obs_ip})..."

    mkdir -p "$(dirname "$mirror_conf")"              # ensure mirror directory exists
    scp "${_SSH_OPTS[@]}" \
        "${SSH_USER_OBSERVER}@${obs_ip}:/opt/homelab/homelab.conf" \
        "$mirror_conf" || return 1                    # abort on transfer failure

    cp "$mirror_conf" "${PATH_HOMELAB_DATA}/config.conf"   # keep local config.conf in sync
    OK "homelab.conf fetched → ${mirror_conf}"

    INFO "Importing settings into homelab_conf.db..."
    _config_init_db                                   # ensure settings table exists

    # Known scalar keys that are source-of-truth values stored in the DB
    local -a scalar_keys=(
        MOUNT_POOL_FAST MOUNT_POOL_BIG
        ID_CLIENT_SHAREDATA IP_SHAREDATA PATH_SHAREDATA_POOL_FAST PATH_SHAREDATA_POOL_BIG
        TIMEOUT_HEARTBEAT_MAX THRESHOLD_PEER_FAIL
        SSH_USER_OBSERVER SSH_USER_HOST _ROUTING_OBSERVER_ID TERMINAL
    )

    # Import each scalar — handles both KEY="value" and KEY=number format
    local key val line
    for key in "${scalar_keys[@]}"; do
        line=$(grep -m1 "^${key}=" "$mirror_conf") || continue   # skip if key absent
        val="${line#*=}"                                          # strip KEY= prefix
        val="${val#\"}"; val="${val%\"}"                          # strip surrounding quotes if present
        [[ -n "$val" ]] && _config_set_value "$key" "$val"
    done

    # Import DEVICENAME_HOST_X, IP_HOST_X, MAC_HOST_X, DEVICENAME_OBSERVER_X, IP_OBSERVER_X
    while IFS= read -r line; do
        key="${line%%=*}"                              # extract key name
        val="${line#*=\"}"; val="${val%\"}"            # extract quoted value
        [[ -n "$key" && -n "$val" ]] && _config_set_value "$key" "$val"
    done < <(grep -E '^(DEVICENAME_HOST_|IP_HOST_|MAC_HOST_|DEVICENAME_OBSERVER_|IP_OBSERVER_)[0-9]+="' "$mirror_conf")

    # Import ZFS_POOLS=( "dataset" ... ) → individual ZFS_POOL_X keys
    local pool_idx=1 in_pools=0
    while IFS= read -r line; do
        [[ "$line" =~ ^ZFS_POOLS=\( ]] && { in_pools=1; continue; }     # enter array block
        (( in_pools )) && [[ "$line" =~ ^\) ]]        && break           # closing paren ends block
        if (( in_pools )); then
            val="${line//\"/}"; val="${val// /}"                          # strip quotes and spaces
            [[ -n "$val" ]] && _config_set_value "ZFS_POOL_${pool_idx}" "$val" && (( pool_idx++ ))
        fi
    done < "$mirror_conf"

    # Import CONF_TARGETS_HOST_X=( id ... ) → space-separated id string per host
    while IFS= read -r line; do
        [[ "$line" =~ ^CONF_TARGETS_HOST_([0-9]+)=\(([^)]*)\) ]] || continue
        local h_id="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]//\"/}"                  # strip all quotes from id list
        val="${val## }"; val="${val%% }"               # trim leading/trailing spaces
        [[ -n "$val" ]] && _config_set_value "CONF_TARGETS_HOST_${h_id}" "$val"
    done < <(grep -E '^CONF_TARGETS_HOST_[0-9]+=' "$mirror_conf")

    OK "DB updated from homelab.conf."
}

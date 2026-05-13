#!/bin/bash
# ==============================================================================
# @meta_name        : config/fetch/main.sh
# @desc_short       : Recover homelab.conf from observer_1 and import into DB.
# ==============================================================================

source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/extension_global.sh"

# ==============================================================================
# --- _default_section_for_key ---
# @desc_short   : Returns the default section label for a given config key.
#                 Used during fetch to assign sections to imported keys.
# @parameter    : $1 | key | Config key name
# ==============================================================================
function _default_section_for_key {
    local key="$1"
    case "$key" in
        MOUNT_POOL_FAST|MOUNT_POOL_BIG)                                  echo "NFS-Share" ;;
        IP_HOST_*|DEVICENAME_HOST_*|MAC_HOST_*)                          echo "Hosts" ;;
        ZFS_POOL_*)                                                       echo "ZFS Pools" ;;
        CONF_TARGETS_HOST_*)                                              echo "Conf Targets" ;;
        IP_OBSERVER_*|DEVICENAME_OBSERVER_*|TIMEOUT_HEARTBEAT_MAX|\
THRESHOLD_PEER_FAIL|HA_OBSERVER_TIMERS)                                  echo "Observer HA" ;;
        ID_CLIENT_SHAREDATA|IP_SHAREDATA|PATH_SHAREDATA_*)               echo "NFS Server" ;;
        SSH_USER_*|_ROUTING_OBSERVER_ID|TERMINAL)                        echo "LPEX Desktop" ;;
        *)                                                                echo "" ;;
    esac
}

# ==============================================================================
# --- extension_start ---
# ==============================================================================
function extension_start {
    local obs_ip
    obs_ip=$(device_ip "observer" "1") || return 1   # resolve observer_1 IP; abort if unavailable
    local mirror_conf="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"

    INFO "Fetching homelab.conf from observer_1 (${obs_ip})..."

    mkdir -p "$(dirname "$mirror_conf")"              # ensure mirror directory exists
    local -a cmd_scp=(scp "${_SSH_OPTS[@]}" \
        "${SSH_USER_OBSERVER}@${obs_ip}:/opt/homelab/homelab.conf" "$mirror_conf")
    "${cmd_scp[@]}" || return 1                       # abort on transfer failure

    cp "$mirror_conf" "${PATH_HOMELAB_DATA}/config.conf"   # keep local config.conf in sync
    OK "homelab.conf fetched → ${mirror_conf}"

    INFO "Importing settings into homelab_conf.db..."
    _config_init_db                                   # ensure settings table exists

    # --- Import simple KEY="value" and KEY=number assignments ---
    # Lines containing $ references are derived (e.g. PATH_SHARE_*) and are skipped
    local key val line section
    for key in \
        MOUNT_POOL_FAST MOUNT_POOL_BIG \
        ID_CLIENT_SHAREDATA IP_SHAREDATA PATH_SHAREDATA_POOL_FAST PATH_SHAREDATA_POOL_BIG \
        TIMEOUT_HEARTBEAT_MAX THRESHOLD_PEER_FAIL \
        SSH_USER_OBSERVER SSH_USER_HOST _ROUTING_OBSERVER_ID TERMINAL
    do
        line=$(grep -m1 "^${key}=" "$mirror_conf") || continue   # skip if key absent from file
        val="${line#*=}"                                          # strip KEY= prefix
        val="${val#\"}"; val="${val%\"}"                          # strip surrounding quotes if present
        [[ -z "$val" ]] && continue                               # skip empty values
        section=$(_default_section_for_key "$key")
        _config_set_value "$key" "$val" "$section"
    done

    # Import DEVICENAME_HOST_X, IP_HOST_X, MAC_HOST_X, DEVICENAME_OBSERVER_X, IP_OBSERVER_X
    while IFS= read -r line; do
        key="${line%%=*}"                              # extract key name (everything before =)
        val="${line#*=\"}"; val="${val%\"}"            # extract quoted value
        [[ -z "$key" || -z "$val" ]] && continue      # skip malformed lines
        section=$(_default_section_for_key "$key")
        _config_set_value "$key" "$val" "$section"
    done < <(grep -E '^(DEVICENAME_HOST_|IP_HOST_|MAC_HOST_|DEVICENAME_OBSERVER_|IP_OBSERVER_)[0-9]+="' "$mirror_conf")

    # Import ZFS_POOLS=( "dataset" ... ) → individual ZFS_POOL_X keys
    local pool_idx=1 in_pools=0
    while IFS= read -r line; do
        [[ "$line" =~ ^ZFS_POOLS=\( ]]     && { in_pools=1; continue; }   # enter array block
        (( in_pools )) && [[ "$line" =~ ^\) ]] && break                    # closing paren ends block
        if (( in_pools )); then
            val="${line//\"/}"; val="${val// /}"                            # strip quotes and spaces
            [[ -z "$val" ]] && continue
            _config_set_value "ZFS_POOL_${pool_idx}" "$val" "ZFS Pools"
            (( pool_idx++ ))
        fi
    done < "$mirror_conf"

    # Import CONF_TARGETS_HOST_X=( id ... ) → space-separated id string per host
    while IFS= read -r line; do
        [[ "$line" =~ ^CONF_TARGETS_HOST_([0-9]+)=\(([^)]*)\) ]] || continue
        local h_id="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]//\"/}"                  # strip all quotes from id list
        val="${val## }"; val="${val%% }"               # trim leading/trailing spaces
        [[ -z "$val" ]] && continue
        _config_set_value "CONF_TARGETS_HOST_${h_id}" "$val" "Conf Targets"
    done < <(grep -E '^CONF_TARGETS_HOST_[0-9]+=' "$mirror_conf")

    # Import HA_OBSERVER_TIMERS array → space-separated string
    if [[ "$(grep -m1 '^HA_OBSERVER_TIMERS=' "$mirror_conf")" =~ ^HA_OBSERVER_TIMERS=\(([^)]*)\) ]]; then
        val="${BASH_REMATCH[1]//\"/}"                  # strip all quotes from timer list
        val="${val## }"; val="${val%% }"               # trim leading/trailing spaces
        [[ -n "$val" ]] && _config_set_value "HA_OBSERVER_TIMERS" "$val" "Observer HA"
    fi

    OK "DB updated from homelab.conf."
}

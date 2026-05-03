#!/bin/bash
# ==============================================================================
# @meta_name        : config/_generate.sh
# @desc_short       : homelab.conf aus homelab_conf.db generieren und deployen.
#                     Sourced by config/push/main.sh.
# ==============================================================================

# ==============================================================================
# --- read_setting ---
# @desc_short   : Reads a single value from the settings table.
# @parameter    : $1 | key     | Settings key
# @parameter    : $2 | default | Default value if key not found
# ==============================================================================
function read_setting {
    local key="$1" default="${2:-}"
    local -a result=()
    lx db --file "homelab_conf.db" --table "settings" --select @result \
        --cols "value" --where "key='${key}'" --limit 1 2>/dev/null
    echo "${result[0]:-$default}"
}

# ==============================================================================
# --- action_generate ---
# @desc_short   : Generates homelab.conf from homelab_conf.db and writes it to
#                 config.conf and the observer_1 mirror.
# ==============================================================================
function action_generate {
    local out_conf="${PATH_HOMELAB_DATA}/config.conf"
    local out_mirror="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"

    INFO "Lese Daten aus homelab_conf.db..."

    # --- Read settings ---
    local mount_fast mount_big
    local ip_sharedata id_sharedata path_sharedata_fast path_sharedata_big
    local timeout_hb threshold_peer
    local ssh_user_obs ssh_user_host routing_obs terminal

    mount_fast=$(read_setting "MOUNT_POOL_FAST" "/mnt/pool_fast/data")
    mount_big=$(read_setting  "MOUNT_POOL_BIG"  "/mnt/pool_big/data")
    id_sharedata=$(read_setting     "ID_CLIENT_SHAREDATA"    "1111")
    ip_sharedata=$(read_setting     "IP_SHAREDATA"           "10.0.200.1")
    path_sharedata_fast=$(read_setting "PATH_SHAREDATA_POOL_FAST" "/zfs-pool-fast/data")
    path_sharedata_big=$(read_setting  "PATH_SHAREDATA_POOL_BIG"  "/zfs-pool-big/data")
    timeout_hb=$(read_setting      "TIMEOUT_HEARTBEAT_MAX" "300")
    threshold_peer=$(read_setting  "THRESHOLD_PEER_FAIL"   "2")
    ssh_user_obs=$(read_setting    "SSH_USER_OBSERVER"     "fadmin")
    ssh_user_host=$(read_setting   "SSH_USER_HOST"         "root")
    routing_obs=$(read_setting     "_ROUTING_OBSERVER_ID"  "1")
    terminal=$(read_setting        "TERMINAL"              "kitty")

    # --- Read hosts ---
    local -a host_rows=()
    lx db --file "homelab_conf.db" --table "hosts" --select @host_rows \
        --cols "id,name,ip,mac" --sort "id ASC" --sep "|" 2>/dev/null

    # --- Read observers ---
    local -a obs_rows=()
    lx db --file "homelab_conf.db" --table "observers" --select @obs_rows \
        --cols "id,name,ip" --sort "id ASC" --sep "|" 2>/dev/null

    # --- Read ZFS pools ---
    local -a pool_rows=()
    lx db --file "homelab_conf.db" --table "zfs_pools" --select @pool_rows \
        --cols "dataset" --sort "id ASC" 2>/dev/null

    # --- Read conf_targets per host ---
    local -a ct_rows=()
    lx db --file "homelab_conf.db" --table "conf_targets" --select @ct_rows \
        --cols "host_id,container_id" --sort "host_id ASC" --sep "|" 2>/dev/null

    # --- Validate minimum data ---
    if (( ${#host_rows[@]} == 0 && ${#obs_rows[@]} == 0 )); then
        ERROR "homelab_conf.db enthält keine Hosts und keine Observer. Zuerst Daten eintragen."
        return 1
    fi

    INFO "Generiere homelab.conf..."

    # --- Build host section ---
    local hosts_section=""
    local first_host_name="" first_obs_name="" last_obs_name=""
    for row in "${host_rows[@]}"; do
        IFS="|" read -r h_id h_name h_ip h_mac <<< "$row"
        [[ -z "$h_id" ]] && continue
        hosts_section+="DEVICENAME_HOST_${h_id}=\"${h_name}\"\n"
        hosts_section+="IP_HOST_${h_id}=\"${h_ip}\"\n"
        hosts_section+="MAC_HOST_${h_id}=\"${h_mac}\"\n\n"
        [[ -z "$first_host_name" ]] && first_host_name="$h_name"
    done

    # --- Build observer section ---
    local obs_section=""
    for row in "${obs_rows[@]}"; do
        IFS="|" read -r o_id o_name o_ip <<< "$row"
        [[ -z "$o_id" ]] && continue
        obs_section+="DEVICENAME_OBSERVER_${o_id}=\"${o_name}\"\n"
        obs_section+="IP_OBSERVER_${o_id}=\"${o_ip}\"\n\n"
        [[ -z "$first_obs_name" ]] && first_obs_name="$o_name"
        last_obs_name="$o_name"
    done

    # --- Build ZFS pools array ---
    local pools_section="ZFS_POOLS=(\n"
    for dataset in "${pool_rows[@]}"; do
        [[ -z "$dataset" ]] && continue
        pools_section+="    \"${dataset}\"\n"
    done
    pools_section+=")"

    # --- Build CONF_TARGETS_HOST_X arrays grouped by host_id ---
    local conf_targets_section=""
    declare -A _ct_map
    for row in "${ct_rows[@]}"; do
        IFS="|" read -r ct_host_id ct_ctid <<< "$row"
        [[ -z "$ct_host_id" || -z "$ct_ctid" ]] && continue
        _ct_map["$ct_host_id"]+=" ${ct_ctid}"
    done
    for h_id in $(echo "${!_ct_map[@]}" | tr ' ' '\n' | sort -n); do
        read -ra _ctids <<< "${_ct_map[$h_id]}"
        conf_targets_section+="CONF_TARGETS_HOST_${h_id}=("
        for ctid in "${_ctids[@]}"; do
            conf_targets_section+=" \"${ctid}\""
        done
        conf_targets_section+=" )\n"
    done
    unset _ct_map

    # --- Build HA timers for first observer (static list) ---
    local ha_timers="HA_OBSERVER_TIMERS=(\"obs-heartbeat.timer\" \"obs-ha-clients-watch.timer\" \"job-backup-nightly.timer\")"

    # --- Build FILE_CONTAINER_LIVE / FILE_VM_LIVE pointing to first host ---
    local first_host_name_for_live="${first_host_name:-host_1}"

    # --- Write file ---
    mkdir -p "$(dirname "$out_conf")"
    mkdir -p "$(dirname "$out_mirror")"

    cat > "$out_conf" << HOMELAB_CONF
# ==============================================================================
# homelab.conf — Single Source of Truth
# GENERIERT von lpex homelab config push — nicht manuell bearbeiten.
# Quelle: ~/.local/state/lpex/data/homelab/homelab_conf.db
#
# Desktop-Config:  ~/.local/state/lpex/data/homelab/config.conf
# Device-Config:   /opt/homelab/homelab.conf  (observer, hosts, clients)
# Deployen:        lpex homelab config push
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. NFS-Share (Mount & Pfade)
# ------------------------------------------------------------------------------
MOUNT_POOL_FAST="${mount_fast}"
MOUNT_POOL_BIG="${mount_big}"

PATH_SHARE_MONITORING="\${MOUNT_POOL_FAST}/homelab_monitoring"
PATH_SHARE_LOGS="\${PATH_SHARE_MONITORING}/logs"
PATH_SHARE_OUTPUTS="\${PATH_SHARE_MONITORING}/outputs"
PATH_SHARE_STATE="\${PATH_SHARE_MONITORING}/state"
PATH_SHARE_METRICS="\${PATH_SHARE_MONITORING}/metrics"

FILE_SHARE_OBSERVER_HEARTBEAT_JSON="\${PATH_SHARE_STATE}/observer_heartbeat.json"

# ------------------------------------------------------------------------------
# 2. Observer — Lokaler State
# ------------------------------------------------------------------------------
PATH_LOCAL_STATE="/opt/homelab/state"
PATH_LOCAL_FLAGS="/opt/homelab/state/flags"
PATH_LOCAL_UNIT_SKIP="/opt/homelab/state/flags/unit_skip"

FILE_LOCAL_OBSERVER_LEADER="\${PATH_LOCAL_FLAGS}/observer_leader"
FILE_LOCAL_HOST_LEADER="\${PATH_LOCAL_FLAGS}/host_leader"
FILE_LOCAL_PEER_FAIL_COUNT="\${PATH_LOCAL_FLAGS}/peer_fail_count"

# ------------------------------------------------------------------------------
# 3. Hosts
# ------------------------------------------------------------------------------
$(printf "%b" "$hosts_section")
# ------------------------------------------------------------------------------
# 4. ZFS-Pools (Replikation observer → host)
# ------------------------------------------------------------------------------
$(printf "%b" "$pools_section")

# ------------------------------------------------------------------------------
# 4b. Conf-Targets (Container die homelab.conf erhalten)
# ------------------------------------------------------------------------------
$(printf "%b" "$conf_targets_section")

# ------------------------------------------------------------------------------
# 5. Observer HA
# ------------------------------------------------------------------------------
$(printf "%b" "$obs_section")
OBSERVER_PRIMARY="${first_obs_name:-observer_1}"
OBSERVER_STANDBY="${last_obs_name:-observer_2}"
TIMEOUT_HEARTBEAT_MAX=${timeout_hb}
THRESHOLD_PEER_FAIL=${threshold_peer}
${ha_timers}

# ------------------------------------------------------------------------------
# 6. NFS-Server (ShareData-Container)
# ------------------------------------------------------------------------------
ID_CLIENT_SHAREDATA="${id_sharedata}"
IP_SHAREDATA="${ip_sharedata}"
PATH_SHAREDATA_POOL_FAST="${path_sharedata_fast}"
PATH_SHAREDATA_POOL_BIG="${path_sharedata_big}"

# ------------------------------------------------------------------------------
# 7. Node-Name (wird beim Sourcen auf Devices gesetzt)
# ------------------------------------------------------------------------------
if [[ -f "/opt/homelab/state/node_name" ]]; then
    NODE_NAME=\$(cat /opt/homelab/state/node_name)
fi

# ------------------------------------------------------------------------------
# Hilfsfunktionen
# ------------------------------------------------------------------------------
function share_mounted {
    mountpoint -q "\$MOUNT_POOL_FAST"
}

function log_daily {
    local message="\$1" status="\${2:-INFO}"
    echo "\$(date '+%H:%M:%S') | \${NODE_NAME:-desktop} | \${0##*/} | \${message} >>> \${status}" \\
        >> "\${LOG_FILE:-/dev/null}"
}

function log_event {
    local message="\$1" status="\${2:-INFO}"
    echo "\$(date -u '+%Y-%m-%dT%H:%M:%SZ') | \${NODE_NAME:-desktop} | \${0##*/} | \${message} >>> \${status}" \\
        >> "\${EVENTS_LOG:-/dev/null}"
}

function unit_skip_active {
    local unit="\$1"
    [[ -f "\${PATH_LOCAL_UNIT_SKIP}/\${unit}" ]]
}

# ==============================================================================
# LPEX-Desktop-Ergänzungen
# Nur auf dem Desktop relevant — auf Devices ohne Wirkung.
# ==============================================================================
SSH_USER_OBSERVER="${ssh_user_obs}"
SSH_USER_HOST="${ssh_user_host}"
_ROUTING_OBSERVER_ID="${routing_obs}"

FILE_CONTAINER_LIVE="\${PATH_SHARE_STATE}/hosts/${first_host_name_for_live}/lxc-live.txt"
FILE_VM_LIVE="\${PATH_SHARE_STATE}/hosts/${first_host_name_for_live}/vm-live.txt"

TERMINAL="${terminal}"
HOMELAB_CONF

    # Mirror-Kopie synchron halten
    cp "$out_conf" "$out_mirror"

    OK "homelab.conf generiert: ${out_conf}"
    OK "Mirror aktualisiert:    ${out_mirror}"
}

# ==============================================================================
# --- action_deploy ---
# @desc_short   : Pushes the generated homelab.conf to observer_1.
# ==============================================================================
function action_deploy {
    local obs_id
    obs_id=$(leader_observer_id)
    local obs_ip
    obs_ip=$(device_ip "observer" "$obs_id") || return 1

    INFO "Pushe homelab.conf auf observer_${obs_id} (${obs_ip})..."

    local mirror_conf="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"
    rsync -az --rsh="ssh ${_SSH_OPTS[*]}" \
        "$mirror_conf" \
        "${SSH_USER_OBSERVER}@${obs_ip}:/opt/homelab/homelab.conf" || return 1

    OK "homelab.conf auf observer_${obs_id} deployed — observer verteilt automatisch weiter."
}

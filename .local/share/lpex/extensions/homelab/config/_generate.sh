#!/bin/bash
# ==============================================================================
# @meta_name        : config/_generate.sh
# @desc_short       : Generate homelab.conf from homelab_conf.db and deploy it.
#                     Sourced by config/push/main.sh.
# ==============================================================================

# ==============================================================================
# --- read_setting ---
# @desc_short   : Reads a single value from the settings table.
# @parameter    : $1 | key     | Settings key
# @parameter    : $2 | default | Default value if key not found (optional)
# ==============================================================================
function read_setting {
    local key="$1" default="${2:-}"
    local esc_key="${key//\'/\'\'}"   # escape single quotes for SQL
    local result                      # scalar — receives single-row output directly
    lx db --file "homelab_conf.db" --table "settings" --select @result \
        --cols "value" --where "key='${esc_key}'" --limit 1 2>/dev/null
    echo "${result:-$default}"        # return found value or the provided default
}

# ==============================================================================
# --- action_generate ---
# @desc_short   : Generates homelab.conf from homelab_conf.db and writes it to
#                 config.conf and the observer_1 mirror.
# ==============================================================================
function action_generate {
    local out_conf="${PATH_HOMELAB_DATA}/config.conf"
    local out_mirror="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"

    INFO "Reading data from homelab_conf.db..."

    # 1. --- Read scalar settings ---
    local mount_fast mount_big
    local id_sharedata ip_sharedata path_sharedata_fast path_sharedata_big
    local timeout_hb threshold_peer ssh_user_obs ssh_user_host routing_obs terminal

    # Read each scalar setting with a sensible fallback default
    mount_fast=$(read_setting           "MOUNT_POOL_FAST"           "/mnt/pool_fast/data")
    mount_big=$(read_setting            "MOUNT_POOL_BIG"            "/mnt/pool_big/data")
    id_sharedata=$(read_setting         "ID_CLIENT_SHAREDATA"       "1111")
    ip_sharedata=$(read_setting         "IP_SHAREDATA"              "10.0.200.1")
    path_sharedata_fast=$(read_setting  "PATH_SHAREDATA_POOL_FAST"  "/zfs-pool-fast/data")
    path_sharedata_big=$(read_setting   "PATH_SHAREDATA_POOL_BIG"   "/zfs-pool-big/data")
    timeout_hb=$(read_setting           "TIMEOUT_HEARTBEAT_MAX"     "300")
    threshold_peer=$(read_setting       "THRESHOLD_PEER_FAIL"       "2")
    ssh_user_obs=$(read_setting         "SSH_USER_OBSERVER"         "fadmin")
    ssh_user_host=$(read_setting        "SSH_USER_HOST"             "root")
    routing_obs=$(read_setting          "_ROUTING_OBSERVER_ID"      "1")
    terminal=$(read_setting             "TERMINAL"                  "kitty")

    # 2. --- Discover hosts by scanning for IP_HOST_* keys ---
    local -a host_key_rows=()
    # Fetch all IP_HOST_X keys sorted by key to get hosts in stable order
    lx db --file "homelab_conf.db" --table "settings" --select @host_key_rows \
        --cols "key" --where "key LIKE 'IP_HOST_%'" --sort "key ASC" 2>/dev/null

    # 3. --- Discover observers by scanning for IP_OBSERVER_* keys ---
    local -a obs_key_rows=()
    # Fetch all IP_OBSERVER_X keys sorted by key
    lx db --file "homelab_conf.db" --table "settings" --select @obs_key_rows \
        --cols "key" --where "key LIKE 'IP_OBSERVER_%'" --sort "key ASC" 2>/dev/null

    # 4. --- Discover ZFS pools by scanning for ZFS_POOL_* keys ---
    local -a pool_vals=()
    # Fetch dataset values only (key ordering already gives correct pool order)
    lx db --file "homelab_conf.db" --table "settings" --select @pool_vals \
        --cols "value" --where "key LIKE 'ZFS_POOL_%'" --sort "key ASC" 2>/dev/null

    # 5. --- Discover conf_target arrays per host ---
    local -a ct_keys=()
    # Fetch key names only — values are looked up per key via read_setting below
    lx db --file "homelab_conf.db" --table "settings" --select @ct_keys \
        --cols "key" --where "key LIKE 'CONF_TARGETS_HOST_%'" --sort "key ASC" 2>/dev/null

    # Validate minimum data — refuse to write an empty config
    if (( ${#host_key_rows[@]} == 0 && ${#obs_key_rows[@]} == 0 )); then
        ERROR "homelab_conf.db contains no hosts and no observers. Add entries first."
        return 1
    fi

    INFO "Generating homelab.conf..."

    # --- Build host section ---
    local hosts_section="" first_host_name=""
    for key in "${host_key_rows[@]}"; do
        local h_id="${key#IP_HOST_}"   # extract numeric ID suffix (e.g. "IP_HOST_1" → "1")
        local h_name h_ip h_mac
        h_name=$(read_setting "DEVICENAME_HOST_${h_id}" "host_${h_id}")
        h_ip=$(read_setting   "IP_HOST_${h_id}"         "")
        h_mac=$(read_setting  "MAC_HOST_${h_id}"        "")
        hosts_section+="DEVICENAME_HOST_${h_id}=\"${h_name}\"\n"
        hosts_section+="IP_HOST_${h_id}=\"${h_ip}\"\n"
        hosts_section+="MAC_HOST_${h_id}=\"${h_mac}\"\n\n"
        [[ -z "$first_host_name" ]] && first_host_name="$h_name"  # first host drives live-file paths
    done

    # --- Build observer section ---
    local obs_section="" first_obs_name="" last_obs_name=""
    for key in "${obs_key_rows[@]}"; do
        local o_id="${key#IP_OBSERVER_}"   # extract numeric ID suffix
        local o_name o_ip
        o_name=$(read_setting "DEVICENAME_OBSERVER_${o_id}" "observer_${o_id}")
        o_ip=$(read_setting   "IP_OBSERVER_${o_id}"         "")
        obs_section+="DEVICENAME_OBSERVER_${o_id}=\"${o_name}\"\n"
        obs_section+="IP_OBSERVER_${o_id}=\"${o_ip}\"\n\n"
        [[ -z "$first_obs_name" ]] && first_obs_name="$o_name"  # first = primary
        last_obs_name="$o_name"                                   # last  = standby
    done

    # --- Build ZFS pools array ---
    local pools_section="ZFS_POOLS=(\n"
    for dataset in "${pool_vals[@]}"; do
        [[ -z "$dataset" ]] && continue             # skip empty entries
        pools_section+="    \"${dataset}\"\n"
    done
    pools_section+=")"

    # --- Build CONF_TARGETS_HOST_X arrays ---
    local conf_targets_section=""
    for ct_key in "${ct_keys[@]}"; do
        local h_id="${ct_key#CONF_TARGETS_HOST_}"   # extract numeric host id suffix
        local ct_val
        ct_val=$(read_setting "CONF_TARGETS_HOST_${h_id}")  # look up space-separated id list
        [[ -z "$ct_val" ]] && continue              # skip hosts with empty target list
        conf_targets_section+="CONF_TARGETS_HOST_${h_id}=("
        for ctid in $ct_val; do
            conf_targets_section+=" \"${ctid}\""   # append each container id as quoted element
        done
        conf_targets_section+=" )\n"
    done

    # --- HA timers static list ---
    local ha_timers="HA_OBSERVER_TIMERS=(\"obs-heartbeat.timer\" \"obs-ha-clients-watch.timer\" \"job-backup-nightly.timer\")"

    # Fall back to host_1 if no hosts are in the DB yet
    local first_host_name_for_live="${first_host_name:-host_1}"

    # --- Write file ---
    mkdir -p "$(dirname "$out_conf")"    # ensure config directory exists
    mkdir -p "$(dirname "$out_mirror")"  # ensure mirror directory exists

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

    # Keep the observer_1 mirror in sync with the newly written config file
    cp "$out_conf" "$out_mirror"

    OK "homelab.conf generated: ${out_conf}"
    OK "Mirror updated:         ${out_mirror}"
}

# ==============================================================================
# --- action_deploy ---
# @desc_short   : Pushes the generated homelab.conf to the leader observer.
# ==============================================================================
function action_deploy {
    local obs_id
    obs_id=$(leader_observer_id)   # determine current leader observer id
    local obs_ip
    obs_ip=$(device_ip "observer" "$obs_id") || return 1   # resolve IP, abort if not found

    INFO "Pushing homelab.conf to observer_${obs_id} (${obs_ip})..."

    local mirror_conf="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"
    # Push mirror file to the observer via rsync over SSH
    rsync -az --rsh="ssh ${_SSH_OPTS[*]}" \
        "$mirror_conf" \
        "${SSH_USER_OBSERVER}@${obs_ip}:/opt/homelab/homelab.conf" || return 1

    OK "homelab.conf deployed to observer_${obs_id} — observer distributes it automatically."
}

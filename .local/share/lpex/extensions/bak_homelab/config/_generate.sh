#!/bin/bash
# ==============================================================================
# @meta_name        : config/_generate.sh
# @desc_short       : Generate homelab.conf from homelab_conf.db and deploy it.
#                     Sourced by config/push/main.sh.
# ==============================================================================

source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/extension_global.sh"

# ==============================================================================
# --- read_setting ---
# @desc_short   : Reads a single value from the settings table.
# @parameter    : $1 | key | Settings key to look up
# ==============================================================================
function read_setting {
    local key="$1"
    local esc_key="${key//\'/\'\'}"   # escape single quotes for SQL
    local result                      # scalar — receives single-row output directly
    lx db --file "homelab_conf.db" --table "settings" --select @result \
        --cols "value" --where "key='${esc_key}'" --limit 1 2>/dev/null
    echo "${result:-}"                # return found value or empty string
}

# ==============================================================================
# --- _init_homelab_functions ---
# @desc_short   : Creates homelab_functions.sh in the data directory on first push
#                 if it does not yet exist. Contains only utility functions and the
#                 NODE_NAME block — no variable assignments that could shadow DB keys.
# ==============================================================================
function _init_homelab_functions {
    local funcs_path="${PATH_HOMELAB_DATA}/homelab_functions.sh"
    [[ -f "$funcs_path" ]] && return   # already present — leave user copy untouched

    cat > "$funcs_path" << 'FUNCS_EOF'
#!/bin/bash
# ==============================================================================
# homelab_functions.sh — Utility functions for all homelab nodes.
# Sourced at the end of homelab.conf (all variables already set at that point).
# Location: ~/.local/state/lpex/data/homelab/  (desktop)
#           /opt/homelab/                       (devices)
# This file is NOT generated. Edit it directly and re-run: lpex homelab config push
# ==============================================================================

# --- Node identification ---
# Read the per-device node name from the state file written at deploy time.
if [[ -f "/opt/homelab/state/node_name" ]]; then
    NODE_NAME=$(cat /opt/homelab/state/node_name)
fi

# ==============================================================================
# --- share_mounted ---
# @desc_short   : Returns 0 if the fast NFS share is mounted, 1 otherwise.
# ==============================================================================
function share_mounted {
    mountpoint -q "$MOUNT_POOL_FAST"
}

# ==============================================================================
# --- log_daily ---
# @desc_short   : Appends a timestamped entry to the daily log file.
# @parameter    : $1 | message | Log message text
# @parameter    : $2 | status  | Status label (default: INFO)
# ==============================================================================
function log_daily {
    local message="$1" status="${2:-INFO}"
    echo "$(date '+%H:%M:%S') | ${NODE_NAME:-desktop} | ${0##*/} | ${message} >>> ${status}" \
        >> "${LOG_FILE:-/dev/null}"
}

# ==============================================================================
# --- log_event ---
# @desc_short   : Appends an ISO-8601 UTC entry to the events log.
# @parameter    : $1 | message | Log message text
# @parameter    : $2 | status  | Status label (default: INFO)
# ==============================================================================
function log_event {
    local message="$1" status="${2:-INFO}"
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') | ${NODE_NAME:-desktop} | ${0##*/} | ${message} >>> ${status}" \
        >> "${EVENTS_LOG:-/dev/null}"
}

# ==============================================================================
# --- unit_skip_active ---
# @desc_short   : Returns 0 if a skip-flag file exists for the given unit.
# @parameter    : $1 | unit | Systemd unit name to check
# ==============================================================================
function unit_skip_active {
    local unit="$1"
    [[ -f "${PATH_LOCAL_UNIT_SKIP}/${unit}" ]]
}
FUNCS_EOF

    INFO "Created homelab_functions.sh in ${PATH_HOMELAB_DATA}"
}

# ==============================================================================
# --- action_generate ---
# @desc_short   : Reads all settings from homelab_conf.db (grouped by section) and
#                 writes homelab.conf. Every variable in the output file comes from
#                 the DB — no hardcoded keys, values, or defaults in this script.
#
#                 Three DB key patterns need special bash array formatting and are
#                 handled explicitly inside the section loop:
#                   ZFS_POOL_X          → aggregated into ZFS_POOLS=( "ds" ... )
#                   CONF_TARGETS_HOST_X → emitted as CONF_TARGETS_HOST_X=( id ... )
#                   HA_OBSERVER_TIMERS  → emitted as HA_OBSERVER_TIMERS=( "t" ... )
#                 All other keys are emitted as plain KEY="value" or KEY=number.
# ==============================================================================
function action_generate {
    local out_conf="${PATH_HOMELAB_DATA}/config.conf"
    local out_mirror="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"
    local db_path="${PATH_EXTENSION_DATA}/homelab_conf.db"

    INFO "Reading settings from homelab_conf.db..."

    # Collect all distinct section labels in alphabetical order
    local -a sections=()
    readarray -t sections < <(sqlite3 "$db_path" \
        "SELECT DISTINCT section FROM settings ORDER BY section;" 2>/dev/null)

    # Refuse to generate from an empty DB
    if (( ${#sections[@]} == 0 )); then
        ERROR "homelab_conf.db contains no entries. Add config values first."
        return 1
    fi

    INFO "Generating homelab.conf..."
    mkdir -p "$(dirname "$out_conf")"    # ensure config directory exists
    mkdir -p "$(dirname "$out_mirror")"  # ensure mirror directory exists

    _init_homelab_functions   # create homelab_functions.sh in state dir if not present

    # --- Write static file header (truncates the output file) ---
    cat > "$out_conf" << 'HOMELAB_HEADER'
# ==============================================================================
# homelab.conf — Single Source of Truth
# Generated by: lpex homelab config push — do not edit manually.
# Source:  ~/.local/state/lpex/data/homelab/homelab_conf.db
#
# Desktop: ~/.local/state/lpex/data/homelab/config.conf
# Devices: /opt/homelab/homelab.conf
# Deploy:  lpex homelab config push
# ==============================================================================
HOMELAB_HEADER

    # --- Write all DB sections ---
    # ZFS_POOL_X datasets are collected across rows in a section and emitted
    # as a single ZFS_POOLS array once all rows for that section are processed.
    local -a zfs_datasets=()

    for section in "${sections[@]}"; do
        local esc_section="${section//\'/\'\'}"   # escape section name for SQL WHERE clause
        local rows
        # Fetch all key-value pairs for this section as "key # value" lines
        lx db --file "homelab_conf.db" --table "settings" --select @rows \
            --cols "key,value" --where "section='${esc_section}'" \
            --sort "key ASC" --sep " # " 2>/dev/null

        [[ -z "$rows" ]] && continue   # skip sections that have no entries

        # Write section header (skipped for entries with no section label)
        if [[ -n "$section" ]]; then
            printf "\n# ------------------------------------------------------------------------------\n" >> "$out_conf"
            printf "# %s\n" "$section" >> "$out_conf"
            printf "# ------------------------------------------------------------------------------\n" >> "$out_conf"
        fi

        zfs_datasets=()   # reset pool dataset collector for each new section

        # --- Format and write each DB row ---
        # Most keys are written as plain KEY="value" lines. Three patterns are
        # exceptions because the consuming scripts expect bash array variables:
        #
        #   ZFS_POOL_X (e.g. ZFS_POOL_1="tank/data")
        #     → scripts use ${ZFS_POOLS[@]} to iterate datasets, not individual
        #       ZFS_POOL_X vars. All datasets are collected here and written as
        #       ZFS_POOLS=( "tank/data" ... ) after the loop.
        #
        #   CONF_TARGETS_HOST_X (e.g. CONF_TARGETS_HOST_1="101 102")
        #     → conf-push iterates ${CONF_TARGETS_HOST_1[@]}. Stored as a
        #       space-separated string in DB, written as a bash array here.
        #
        #   HA_OBSERVER_TIMERS (e.g. "obs-heartbeat.timer obs-ha.timer")
        #     → observer uses ${HA_OBSERVER_TIMERS[@]} to enable/disable timers.
        #       Same space-separated → array conversion as CONF_TARGETS.
        while IFS= read -r row; do
            [[ -z "$row" ]] && continue
            local key="${row%% # *}"   # everything before " # " = key
            local val="${row##* # }"   # everything after  " # " = value

            if [[ "$key" =~ ^ZFS_POOL_[0-9]+$ ]]; then
                zfs_datasets+=("$val")   # defer — written as ZFS_POOLS array after loop

            elif [[ "$key" =~ ^CONF_TARGETS_HOST_([0-9]+)$ ]]; then
                printf "CONF_TARGETS_HOST_%s=(" "${BASH_REMATCH[1]}" >> "$out_conf"
                for ctid in $val; do printf " \"%s\"" "$ctid" >> "$out_conf"; done
                printf " )\n" >> "$out_conf"

            elif [[ "$key" == "HA_OBSERVER_TIMERS" ]]; then
                printf "HA_OBSERVER_TIMERS=(" >> "$out_conf"
                for timer in $val; do printf " \"%s\"" "$timer" >> "$out_conf"; done
                printf " )\n" >> "$out_conf"

            else
                # Plain scalar: numeric values without quotes, all others with quotes
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    printf "%s=%s\n" "$key" "$val" >> "$out_conf"
                else
                    printf "%s=\"%s\"\n" "$key" "$val" >> "$out_conf"
                fi
            fi
        done <<< "$rows"

        # Emit the aggregated ZFS_POOLS array (only when this section had ZFS_POOL_X keys)
        if (( ${#zfs_datasets[@]} > 0 )); then
            printf "ZFS_POOLS=(\n" >> "$out_conf"
            for ds in "${zfs_datasets[@]}"; do printf "    \"%s\"\n" "$ds" >> "$out_conf"; done
            printf ")\n" >> "$out_conf"
        fi
    done

    # Source homelab_functions.sh at the very end so all DB variables are already
    # set when it is evaluated. BASH_SOURCE[0]%/* resolves to the directory of the
    # sourced file — works identically on desktop (config.conf) and devices (homelab.conf).
    printf "\nsource \"\${BASH_SOURCE[0]%%/*}/homelab_functions.sh\"\n" >> "$out_conf"

    cp "$out_conf" "$out_mirror"   # keep observer_1 mirror in sync

    OK "homelab.conf generated: ${out_conf}"
    OK "Mirror updated:         ${out_mirror}"
}

# ==============================================================================
# --- action_deploy ---
# @desc_short   : Pushes homelab.conf and homelab_functions.sh to the leader observer
#                 via rsync over SSH.
# ==============================================================================
function action_deploy {
    local obs_id
    obs_id=$(leader_observer_id)   # determine current leader observer id
    local obs_ip
    obs_ip=$(device_ip "observer" "$obs_id") || return 1   # resolve IP; abort if not found

    INFO "Pushing homelab.conf to observer_${obs_id} (${obs_ip})..."

    local mirror_conf="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"
    local local_funcs="${PATH_HOMELAB_DATA}/homelab_functions.sh"

    # Push both files to /opt/homelab/ on the observer in one transfer
    lx cmd --run "rsync -az --rsh='ssh ${_SSH_OPTS[*]}' '${mirror_conf}' '${local_funcs}' '${SSH_USER_OBSERVER}@${obs_ip}:/opt/homelab/'" \
        --show-cmd --exit-on-fail --error-msg "Failed to deploy to observer_${obs_id}"

    OK "Deployed to observer_${obs_id} — observer distributes both files automatically."
}

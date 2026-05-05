#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @desc_short       : Shared helpers for all homelab submodules.
#                     Auto-sourced by LPEX once before arguments() runs.
# ==============================================================================

_SSH_OPTS=(-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10)

# Convenience alias — safe here because extension_global.sh is sourced in Phase 4
# (after PATH_EXTENSION_DATA is set by the LPEX auto-loader).
PATH_HOMELAB_DATA="${PATH_EXTENSION_DATA}"


# ==============================================================================
# --- validate_device ---
# @desc_short   : Ensures exactly one target device is selected.
#                 Sets globals _DEVICE_TYPE and _DEVICE_ID on success.
# @usage        : validate_device || return 1
# ==============================================================================
function validate_device {
    local count=0
    declare -g _DEVICE_TYPE=""
    declare -g _DEVICE_ID=""

    if [[ -n "$ARG_HOST" ]];      then (( count++ )); _DEVICE_TYPE="host";      _DEVICE_ID="$ARG_HOST";      fi
    if [[ -n "$ARG_OBSERVER" ]];  then (( count++ )); _DEVICE_TYPE="observer";  _DEVICE_ID="$ARG_OBSERVER";  fi
    if [[ -n "$ARG_CONTAINER" ]]; then (( count++ )); _DEVICE_TYPE="container"; _DEVICE_ID="$ARG_CONTAINER"; fi
    if [[ -n "$ARG_VM" ]];        then (( count++ )); _DEVICE_TYPE="vm";        _DEVICE_ID="$ARG_VM";        fi

    if (( count != 1 )); then
        ERROR "Exactly one target device required (--host, --observer, --container, or --vm)."
        return 1
    fi
}

# ==============================================================================
# --- device_ip ---
# @desc_short   : Returns the IP of a host or observer.
#                 Tries homelab_conf.db first, falls back to config.conf vars.
# @parameter    : $1 | type | "host" or "observer"
# @parameter    : $2 | id   | Numeric ID (e.g. 1, 2)
# ==============================================================================
function device_ip {
    local type="$1" id="$2"

    # Build the flat settings key for this device (e.g. IP_HOST_1, IP_OBSERVER_2)
    local varname
    case "$type" in
        host)     varname="IP_HOST_${id}" ;;
        observer) varname="IP_OBSERVER_${id}" ;;
        *) ERROR "Unknown device type for IP lookup: $type"; return 1 ;;
    esac

    # Try the flat settings table first if the DB exists
    if [[ -f "${PATH_HOMELAB_DATA}/homelab_conf.db" ]]; then
        local esc_key="${varname//\'/\'\'}"   # escape key for SQL
        local -a _db_result=()
        lx db --file "homelab_conf.db" --table "settings" --select @_db_result \
            --cols "value" --where "key='${esc_key}'" --limit 1 2>/dev/null
        if [[ -n "${_db_result[0]:-}" ]]; then
            echo "${_db_result[0]}"
            return 0
        fi
    fi

    # Fall back to config.conf variables (IP_HOST_1, IP_OBSERVER_2, etc.)
    local ip="${!varname:-}"
    if [[ -z "$ip" ]]; then
        ERROR "No IP found for ${type} ${id} — set ${varname} in config.conf or homelab_conf.db"
        return 1
    fi
    echo "$ip"
}

# ==============================================================================
# --- device_name ---
# @desc_short   : Returns the logical name of a host or observer (e.g. "host_1").
# @parameter    : $1 | type | "host" or "observer"
# @parameter    : $2 | id   | Numeric ID
# ==============================================================================
function device_name {
    local type="$1" id="$2"

    # Build the flat settings key for this device name (e.g. DEVICENAME_HOST_1)
    local varname
    case "$type" in
        host)     varname="DEVICENAME_HOST_${id}" ;;
        observer) varname="DEVICENAME_OBSERVER_${id}" ;;
        *)        echo "${type}_${id}"; return 0 ;;   # unknown type: fall back to convention
    esac

    # Try the flat settings table first if the DB exists
    if [[ -f "${PATH_HOMELAB_DATA}/homelab_conf.db" ]]; then
        local esc_key="${varname//\'/\'\'}"   # escape key for SQL
        local -a _r=()
        lx db --file "homelab_conf.db" --table "settings" --select @_r \
            --cols "value" --where "key='${esc_key}'" --limit 1 2>/dev/null
        [[ -n "${_r[0]:-}" ]] && echo "${_r[0]}" && return 0
    fi

    # Fall back to <type>_<id> convention
    echo "${type}_${id}"
}

# ==============================================================================
# --- leader_observer_id ---
# @desc_short   : Returns the ID of the current leader observer.
#                 Reads from NFS state if available, falls back to config default.
# ==============================================================================
function leader_observer_id {
    # Try reading the leader name from NFS observer health state
    local leader_name
    for obs_status in "${PATH_SHARE_STATE}/observers"/*/status.json; do
        if [[ -f "$obs_status" ]]; then
            leader_name=$(jq -r '.observer_leader // empty' "$obs_status" 2>/dev/null)
            [[ -n "$leader_name" ]] && break
        fi
    done

    # If leader name found, extract numeric ID suffix (e.g. "observer_1" → "1")
    if [[ -n "${leader_name:-}" ]]; then
        echo "${leader_name##*_}"
        return 0
    fi

    # Fall back to config default
    echo "${_ROUTING_OBSERVER_ID:-1}"
}

# ==============================================================================
# --- run_on_observer ---
# @desc_short   : Runs a command on an observer via direct SSH.
# @parameter    : $1 | id  | Observer ID
# @parameter    : $2 | cmd | Command to execute
# ==============================================================================
function run_on_observer {
    local id="$1" cmd="$2"
    local ip
    ip=$(device_ip "observer" "$id") || return 1
    ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${ip}" "$cmd"
}

# ==============================================================================
# --- run_on_host ---
# @desc_short   : Runs a command on a host, routed through the leader observer.
# @parameter    : $1 | id  | Host ID
# @parameter    : $2 | cmd | Command to execute
# ==============================================================================
function run_on_host {
    local id="$1" cmd="$2"
    local host_ip obs_id obs_ip
    host_ip=$(device_ip "host" "$id") || return 1
    obs_id=$(leader_observer_id)
    obs_ip=$(device_ip "observer" "$obs_id") || return 1
    ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
        "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} '${cmd}'"
}

# ==============================================================================
# --- host_for_container ---
# @desc_short   : Finds the host ID that currently runs a container.
#                 Reads from NFS lxc-live.txt files.
# @parameter    : $1 | ctid | Container ID (VMID)
# ==============================================================================
function host_for_container {
    local ctid="$1"

    local live_file
    for live_file in "${PATH_SHARE_STATE}/hosts"/*/lxc-live.txt; do
        [[ -f "$live_file" ]] || continue
        if grep -q "^${ctid} #" "$live_file" 2>/dev/null; then
            local host_name
            host_name=$(basename "$(dirname "$live_file")")
            echo "${host_name##*_}"
            return 0
        fi
    done

    ERROR "Container ${ctid} not found in any host live file (NFS may not be mounted)"
    return 1
}

# ==============================================================================
# --- host_for_vm ---
# @desc_short   : Finds the host ID that currently runs a VM.
#                 Reads from NFS vm-live.txt files.
# @parameter    : $1 | vmid | VM ID (VMID)
# ==============================================================================
function host_for_vm {
    local vmid="$1"

    local live_file
    for live_file in "${PATH_SHARE_STATE}/hosts"/*/vm-live.txt; do
        [[ -f "$live_file" ]] || continue
        if grep -q "^${vmid} " "$live_file" 2>/dev/null; then
            local host_name
            host_name=$(basename "$(dirname "$live_file")")
            echo "${host_name##*_}"
            return 0
        fi
    done

    ERROR "VM ${vmid} not found in any host live file (NFS may not be mounted)"
    return 1
}

# ==============================================================================
# --- run_on_container ---
# @desc_short   : Runs a command inside a container via pct exec.
# @parameter    : $1 | ctid | Container ID (VMID)
# @parameter    : $2 | cmd  | Command to execute inside the container
# ==============================================================================
function run_on_container {
    local ctid="$1" cmd="$2"
    local host_id host_ip obs_id obs_ip
    host_id=$(host_for_container "$ctid") || return 1
    host_ip=$(device_ip "host" "$host_id") || return 1
    obs_id=$(leader_observer_id)
    obs_ip=$(device_ip "observer" "$obs_id") || return 1
    ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
        "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
        'pct exec ${ctid} -- bash -c ${cmd@Q}'"
}

# ==============================================================================
# --- run_on_device ---
# @desc_short   : Routes a command to the correct device based on type.
# @parameter    : $1 | type | Device type (observer, host, container, vm)
# @parameter    : $2 | id   | Device ID
# @parameter    : $3 | cmd  | Command to execute
# ==============================================================================
function run_on_device {
    local type="$1" id="$2" cmd="$3"
    case "$type" in
        observer)  run_on_observer  "$id" "$cmd" ;;
        host)      run_on_host      "$id" "$cmd" ;;
        container) run_on_container "$id" "$cmd" ;;
        vm)
            local host_id host_ip obs_id obs_ip
            host_id=$(host_for_vm "$id") || return 1
            host_ip=$(device_ip "host" "$host_id") || return 1
            obs_id=$(leader_observer_id)
            obs_ip=$(device_ip "observer" "$obs_id") || return 1
            local -a _vm_ip_r=()
            lx db --file "homelab_conf.db" --table "vms" --select @_vm_ip_r \
                --cols "ip" --where "id=${id}" --limit 1 2>/dev/null
            local vm_ip="${_vm_ip_r[0]:-}"
            if [[ -n "$vm_ip" ]]; then
                ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                    "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                    'ssh ${_SSH_OPTS[*]} root@${vm_ip} ${cmd@Q}'"
            else
                ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                    "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                    'qm guest exec ${id} -- bash -c ${cmd@Q}'"
            fi
            ;;
        *) ERROR "Unknown device type: $type"; return 1 ;;
    esac
}

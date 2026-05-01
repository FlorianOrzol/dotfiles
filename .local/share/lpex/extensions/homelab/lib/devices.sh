#!/bin/bash
# ==============================================================================
# @meta_name        : lib/devices.sh
# @desc_short       : SSH routing and device resolution for all homelab submodules.
#                     Sourced via variables.sh — do not call directly.
# ==============================================================================

_SSH_OPTS=(-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10)

# ==============================================================================
# --- _device_ip ---
# @desc_short   : Returns the IP of a host or observer.
#                 Tries homelab_conf.db first, falls back to config.conf vars.
# @parameter    : $1 | type | "host" or "observer"
# @parameter    : $2 | id   | Numeric ID (e.g. 1, 2)
# ==============================================================================
function _device_ip {
    local type="$1" id="$2"

    # Try homelab_conf.db if it exists — flexible, DB-driven source of truth
    if [[ -f "${PATH_HOMELAB_DATA}/homelab_conf.db" ]]; then
        local table
        # Select table based on device type
        case "$type" in
            host)     table="hosts" ;;
            observer) table="observers" ;;
        esac
        if [[ -n "$table" ]]; then
            local -a _db_result=()
            lx db --file "homelab_conf.db" --table "$table" --select @_db_result \
                --cols "ip" --where "id='${id}'" --limit 1 2>/dev/null
            # Return DB result if found
            if [[ -n "${_db_result[0]:-}" ]]; then
                echo "${_db_result[0]}"
                return 0
            fi
        fi
    fi

    # Fall back to config.conf variables (IP_HOST_1, IP_OBSERVER_2, etc.)
    local varname
    case "$type" in
        host)     varname="IP_HOST_${id}" ;;
        observer) varname="IP_OBSERVER_${id}" ;;
        *) ERROR "Unknown device type for IP lookup: $type"; return 1 ;;
    esac

    local ip="${!varname:-}"
    # Abort if no IP was found by either method
    if [[ -z "$ip" ]]; then
        ERROR "No IP found for ${type} ${id} — set IP_${type^^}_${id} in config.conf or add to homelab_conf.db"
        return 1
    fi
    echo "$ip"
}

# ==============================================================================
# --- _device_name ---
# @desc_short   : Returns the logical name of a host or observer (e.g. "host_1").
# @parameter    : $1 | type | "host" or "observer"
# @parameter    : $2 | id   | Numeric ID
# ==============================================================================
function _device_name {
    local type="$1" id="$2"

    # Try DB first
    if [[ -f "${PATH_HOMELAB_DATA}/homelab_conf.db" ]]; then
        local table
        case "$type" in
            host)     table="hosts" ;;
            observer) table="observers" ;;
        esac
        if [[ -n "$table" ]]; then
            local -a _r=()
            lx db --file "homelab_conf.db" --table "$table" --select @_r \
                --cols "name" --where "id='${id}'" --limit 1 2>/dev/null
            [[ -n "${_r[0]:-}" ]] && echo "${_r[0]}" && return 0
        fi
    fi

    # Fall back to <type>_<id> convention
    echo "${type}_${id}"
}

# ==============================================================================
# --- _leader_observer_id ---
# @desc_short   : Returns the ID of the current leader observer.
#                 Reads from NFS state if available, falls back to config default.
# ==============================================================================
function _leader_observer_id {
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
# --- _run_on_observer ---
# @desc_short   : Runs a command on an observer via direct SSH.
# @parameter    : $1 | id  | Observer ID
# @parameter    : $2 | cmd | Command to execute
# ==============================================================================
function _run_on_observer {
    local id="$1" cmd="$2"
    local ip
    ip=$(_device_ip "observer" "$id") || return 1
    ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${ip}" "$cmd"
}

# ==============================================================================
# --- _run_on_host ---
# @desc_short   : Runs a command on a host, routed through the leader observer.
# @parameter    : $1 | id  | Host ID
# @parameter    : $2 | cmd | Command to execute
# ==============================================================================
function _run_on_host {
    local id="$1" cmd="$2"
    local host_ip obs_id obs_ip
    host_ip=$(_device_ip "host" "$id") || return 1
    obs_id=$(_leader_observer_id)
    obs_ip=$(_device_ip "observer" "$obs_id") || return 1
    ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
        "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} '${cmd}'"
}

# ==============================================================================
# --- _host_for_container ---
# @desc_short   : Finds the host ID that currently runs a container.
#                 Reads from NFS lxc-live.txt files.
# @parameter    : $1 | ctid | Container ID (VMID)
# ==============================================================================
function _host_for_container {
    local ctid="$1"

    # Check each host's live file for this CTID
    local live_file
    for live_file in "${PATH_SHARE_STATE}/hosts"/*/lxc-live.txt; do
        # Skip if file does not exist
        [[ -f "$live_file" ]] || continue
        # Check if this CTID is listed as running or stopped in this host's live file
        if grep -q "^${ctid} #" "$live_file" 2>/dev/null; then
            # Extract host name from path: .../hosts/host_1/lxc-live.txt → "host_1"
            local host_name
            host_name=$(basename "$(dirname "$live_file")")
            # Return the numeric ID suffix: "host_1" → "1"
            echo "${host_name##*_}"
            return 0
        fi
    done

    ERROR "Container ${ctid} not found in any host live file (NFS may not be mounted)"
    return 1
}

# ==============================================================================
# --- _run_on_container ---
# @desc_short   : Runs a command inside a container via pct exec, routed through
#                 the leader observer and the container's host.
# @parameter    : $1 | ctid | Container ID (VMID)
# @parameter    : $2 | cmd  | Command to execute inside the container
# ==============================================================================
function _run_on_container {
    local ctid="$1" cmd="$2"
    local host_id host_ip obs_id obs_ip
    host_id=$(_host_for_container "$ctid") || return 1
    host_ip=$(_device_ip "host" "$host_id") || return 1
    obs_id=$(_leader_observer_id)
    obs_ip=$(_device_ip "observer" "$obs_id") || return 1
    ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
        "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
        'pct exec ${ctid} -- bash -c ${cmd@Q}'"
}

# ==============================================================================
# --- _run_on_device ---
# @desc_short   : Routes a command to the correct device based on type.
# @parameter    : $1 | type | Device type (observer, host, container, vm)
# @parameter    : $2 | id   | Device ID
# @parameter    : $3 | cmd  | Command to execute
# ==============================================================================
function _run_on_device {
    local type="$1" id="$2" cmd="$3"
    case "$type" in
        observer)  _run_on_observer  "$id" "$cmd" ;;
        host)      _run_on_host      "$id" "$cmd" ;;
        container) _run_on_container "$id" "$cmd" ;;
        vm)
            # VMs: route via host, use SSH to VM's IP (requires guest SSH enabled)
            local host_id host_ip obs_id obs_ip vm_ip
            host_id=$(_host_for_container "$id") || return 1
            host_ip=$(_device_ip "host" "$host_id") || return 1
            obs_id=$(_leader_observer_id)
            obs_ip=$(_device_ip "observer" "$obs_id") || return 1
            # Get VM IP from DB if available; otherwise fall back to qm guest exec
            local -a _vm_ip_r=()
            lx db --file "homelab_conf.db" --table "vms" --select @_vm_ip_r \
                --cols "ip" --where "id='${id}'" --limit 1 2>/dev/null
            vm_ip="${_vm_ip_r[0]:-}"
            if [[ -n "$vm_ip" ]]; then
                # SSH via observer → host → VM
                ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                    "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                    'ssh ${_SSH_OPTS[*]} root@${vm_ip} ${cmd@Q}'"
            else
                # Fall back: qm guest exec via observer → host
                ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                    "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                    'qm guest exec ${id} -- bash -c ${cmd@Q}'"
            fi
            ;;
        *) ERROR "Unknown device type: $type"; return 1 ;;
    esac
}

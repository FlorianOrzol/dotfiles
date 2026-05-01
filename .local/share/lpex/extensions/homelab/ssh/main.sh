#!/bin/bash
# ==============================================================================
# @meta_name        : ssh/main.sh
# @desc_short       : Opens an interactive SSH session on the target device.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short   : Validates device selection and opens the appropriate session.
# ==============================================================================
function extension_start {
    _validate_device || return 1

    # Route to device-type-specific SSH handler
    case "$_DEVICE_TYPE" in
        observer)  _ssh_observer  "$_DEVICE_ID" ;;
        host)      _ssh_host      "$_DEVICE_ID" ;;
        container) _ssh_container "$_DEVICE_ID" ;;
        vm)        _ssh_vm        "$_DEVICE_ID" ;;
    esac
}

# ==============================================================================
# --- _ssh_observer ---
# @desc_short   : Opens direct SSH session to an observer.
# ==============================================================================
function _ssh_observer {
    local id="$1"
    local ip
    ip=$(_device_ip "observer" "$id") || return 1
    local name
    name=$(_device_name "observer" "$id")
    INFO "Connecting to observer ${name} (${SSH_USER_OBSERVER}@${ip})..."
    ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${ip}"
}

# ==============================================================================
# --- _ssh_host ---
# @desc_short   : Opens SSH session to a host, tunnelled through the leader observer.
# ==============================================================================
function _ssh_host {
    local id="$1"
    local host_ip obs_id obs_ip
    host_ip=$(_device_ip "host" "$id") || return 1
    obs_id=$(_leader_observer_id)
    obs_ip=$(_device_ip "observer" "$obs_id") || return 1
    local name
    name=$(_device_name "host" "$id")
    INFO "Connecting to host ${name} (via observer ${obs_id})..."
    ssh "${_SSH_OPTS[@]}" -J "${SSH_USER_OBSERVER}@${obs_ip}" \
        "${SSH_USER_HOST}@${host_ip}"
}

# ==============================================================================
# --- _ssh_container ---
# @desc_short   : Enters a container via pct enter, routed through observer → host.
# ==============================================================================
function _ssh_container {
    local ctid="$1"
    local host_id host_ip obs_id obs_ip
    host_id=$(_host_for_container "$ctid") || return 1
    host_ip=$(_device_ip "host" "$host_id") || return 1
    obs_id=$(_leader_observer_id)
    obs_ip=$(_device_ip "observer" "$obs_id") || return 1
    INFO "Entering container ${ctid} via host_${host_id}..."
    ssh "${_SSH_OPTS[@]}" -t \
        -J "${SSH_USER_OBSERVER}@${obs_ip}" \
        "${SSH_USER_HOST}@${host_ip}" \
        "pct enter ${ctid}"
}

# ==============================================================================
# --- _ssh_vm ---
# @desc_short   : Opens SSH to a VM via jump through observer → host → VM IP.
# ==============================================================================
function _ssh_vm {
    local vmid="$1"
    local host_id host_ip obs_id obs_ip vm_ip
    host_id=$(_host_for_container "$vmid") || return 1
    host_ip=$(_device_ip "host" "$host_id") || return 1
    obs_id=$(_leader_observer_id)
    obs_ip=$(_device_ip "observer" "$obs_id") || return 1

    # Look up VM IP from DB
    local -a _r=()
    lx db --file "homelab_conf.db" --table "vms" --select @_r \
        --cols "ip" --where "id='${vmid}'" --limit 1 2>/dev/null
    vm_ip="${_r[0]:-}"

    # Abort if no VM IP is available — cannot SSH without an address
    if [[ -z "$vm_ip" ]]; then
        ERROR "No IP found for VM ${vmid} in homelab_conf.db — add it to enable SSH."
        return 1
    fi

    INFO "Connecting to VM ${vmid} (${vm_ip}) via host_${host_id}..."
    ssh "${_SSH_OPTS[@]}" \
        -J "${SSH_USER_OBSERVER}@${obs_ip},${SSH_USER_HOST}@${host_ip}" \
        "root@${vm_ip}"
}

#!/bin/bash
# ==============================================================================
# @meta_name        : _connect.sh
# @desc_short       : SSH connection handlers for each device type.
#                     Sourced by ssh/main.sh.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"  # common SSH flags

# ==============================================================================
# --- ssh_observer ---
# @desc_short  : Opens a direct SSH session to an observer.
# @usage       : ssh_observer <device>
# @parameter   : $1 | device | Observer name (e.g. observer_1)
# @notes       : Observers are directly reachable — no proxy jump needed.
# ==============================================================================
function ssh_observer {
    local device="$1"
    local ip user

    # Resolve observer IP and SSH user from config.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    INFO "Connecting to observer '${device}' (${user}@${ip})..."
    # Direct SSH — observer is reachable from desktop without a proxy.
    ssh ${SSH_OPTS} "${user}@${ip}"
}

# ==============================================================================
# --- ssh_host ---
# @desc_short  : Opens an SSH session to a host via ProxyJump through OBSERVER_PRIMARY.
# @usage       : ssh_host <device>
# @parameter   : $1 | device | Host name (e.g. host_1)
# @notes       : Hosts are on the internal network — desktop reaches them only
#                through the observer as a jump host.
# ==============================================================================
function ssh_host {
    local device="$1"
    local host_ip proxy_ip proxy_user

    # Resolve host IP from config.
    host_ip=$(get_device_ip "$device") || return 1

    # OBSERVER_PRIMARY is the designated proxy jump host for reaching internal devices.
    proxy_ip=$(get_device_ip "$OBSERVER_PRIMARY")         || return 1
    proxy_user=$(get_device_ssh_user "$OBSERVER_PRIMARY") || return 1

    INFO "Connecting to host '${device}' via observer '${OBSERVER_PRIMARY}'..."
    # ProxyJump: desktop → OBSERVER_PRIMARY → host.
    ssh ${SSH_OPTS} -J "${proxy_user}@${proxy_ip}" "${SSH_USER_HOST}@${host_ip}"
}

# ==============================================================================
# --- ssh_container ---
# @desc_short  : Enters a container shell via pct enter, routed through observer → host.
# @usage       : ssh_container <container_id>
# @parameter   : $1 | container_id | Proxmox container ID (e.g. 101)
# @notes       : pct enter requires an interactive TTY — -t flag is mandatory.
#                The host running the container is resolved dynamically.
# ==============================================================================
function ssh_container {
    local container_id="$1"
    local host host_ip host_user proxy_ip proxy_user

    # Determine which host is currently running this container.
    host=$(find_container_host "$container_id") || return 1
    host_ip=$(get_device_ip "$host")             || return 1
    host_user=$(get_device_ssh_user "$host")     || return 1

    # OBSERVER_PRIMARY is the designated proxy jump host.
    proxy_ip=$(get_device_ip "$OBSERVER_PRIMARY")         || return 1
    proxy_user=$(get_device_ssh_user "$OBSERVER_PRIMARY") || return 1

    INFO "Entering container '${container_id}' on host '${host}' via observer '${OBSERVER_PRIMARY}'..."
    # -t allocates a pseudo-TTY required by pct enter for an interactive shell.
    # ProxyJump: desktop → OBSERVER_PRIMARY → host → pct enter container.
    ssh ${SSH_OPTS} -t \
        -J "${proxy_user}@${proxy_ip}" \
        "${host_user}@${host_ip}" \
        "pct enter ${container_id}"
}

# ==============================================================================
# --- ssh_vm ---
# @desc_short  : Opens an SSH session to a VM via double ProxyJump through observer → host.
# @usage       : ssh_vm <vm_id>
# @parameter   : $1 | vm_id | Proxmox VM ID (e.g. 201)
# @notes       : VM IP is resolved via QEMU guest agent — agent must be running.
#                Routing: desktop → OBSERVER_PRIMARY → host → VM.
# ==============================================================================
function ssh_vm {
    local vm_id="$1"
    local host host_ip host_user proxy_ip proxy_user vm_ip

    # Determine which host is currently running this VM.
    host=$(find_vm_host "$vm_id")            || return 1
    host_ip=$(get_device_ip "$host")          || return 1
    host_user=$(get_device_ssh_user "$host")  || return 1

    # OBSERVER_PRIMARY is the designated proxy jump host.
    proxy_ip=$(get_device_ip "$OBSERVER_PRIMARY")         || return 1
    proxy_user=$(get_device_ssh_user "$OBSERVER_PRIMARY") || return 1

    # Resolve the VM's primary IP via QEMU guest agent on its host.
    vm_ip=$(get_vm_ip "$vm_id") || return 1

    INFO "Connecting to VM '${vm_id}' (${vm_ip}) via observer '${OBSERVER_PRIMARY}' and host '${host}'..."
    # Double ProxyJump: desktop → OBSERVER_PRIMARY → host → VM.
    ssh ${SSH_OPTS} \
        -J "${proxy_user}@${proxy_ip},${host_user}@${host_ip}" \
        "root@${vm_ip}"
}

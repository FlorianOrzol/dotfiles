#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @desc_short       : Shared device-list and SSH helpers for all homelab submodules.
# ==============================================================================

# --- get_hosts ---
# @desc_short  : Prints all configured host names, one per line.
# @usage       : get_hosts
# ==============================================================================
function get_hosts {
    printf '%s\n' "${HOSTS[@]}"             # emit each host name from config array
}

# --- get_observers ---
# @desc_short  : Prints all configured observer names, one per line.
# @usage       : get_observers
# ==============================================================================
function get_observers {
    printf '%s\n' "${OBSERVERS[@]}"         # emit each observer name from config array
}

# --- get_nodes ---
# @desc_short  : Prints all physical node names (hosts + observers), one per line.
# @usage       : get_nodes
# ==============================================================================
function get_nodes {
    get_hosts                               # all hosts
    get_observers                           # all observers
}

# --- get_containers ---
# @desc_short  : Prints live container names from NFS share, one per line.
# @usage       : get_containers
# ==============================================================================
function get_containers {
    share_mounted             || return 0   # skip silently if NFS share not mounted
    [[ -f "$FILE_CONTAINER_LIVE" ]] || return 0   # skip if live file missing
    cat "$FILE_CONTAINER_LIVE"              # emit container names from live file
}

# --- get_vms ---
# @desc_short  : Prints live VM names from NFS share, one per line.
# @usage       : get_vms
# ==============================================================================
function get_vms {
    share_mounted             || return 0   # skip silently if NFS share not mounted
    [[ -f "$FILE_VM_LIVE" ]] || return 0   # skip if live file missing
    cat "$FILE_VM_LIVE"                     # emit VM names from live file
}

# --- get_cmd_current_alias ---
# @desc_short  : Prints the alias of the currently selected entry (pre-fill for edit).
# @usage       : get_cmd_current_alias
# ==============================================================================
function get_cmd_current_alias {
    local value
    lx db --file "cmds.db" --table "commands" --select @value \
        --cols "alias" --where "alias='${ARG_ALIAS}'" --limit 1
    echo "$value"
}

# --- get_cmd_current_cmd ---
# @desc_short  : Prints the cmd of the currently selected entry (pre-fill for edit).
# @usage       : get_cmd_current_cmd
# ==============================================================================
function get_cmd_current_cmd {
    local value
    lx db --file "cmds.db" --table "commands" --select @value \
        --cols "cmd" --where "alias='${ARG_ALIAS}'" --limit 1
    echo "$value"
}

# --- get_cmd_current_description ---
# @desc_short  : Prints the description of the currently selected entry (pre-fill for edit).
# @usage       : get_cmd_current_description
# ==============================================================================
function get_cmd_current_description {
    local value
    lx db --file "cmds.db" --table "commands" --select @value \
        --cols "description" --where "alias='${ARG_ALIAS}'" --limit 1
    echo "$value"
}

# --- get_cmd_current_devices ---
# @desc_short  : Prints all devices that have the currently selected alias, one per line.
# @usage       : get_cmd_current_devices
# ==============================================================================
function get_cmd_current_devices {
    declare -a rows
    lx db --file "cmds.db" --table "commands" --select @rows \
        --cols "device" --where "alias='${ARG_ALIAS}'"
    printf '%s\n' "${rows[@]}"
}

# --- get_cmd_aliases ---
# @desc_short  : Prints all saved command aliases with their device as "alias # device", one per line.
# @usage       : get_cmd_aliases
# ==============================================================================
function get_cmd_aliases {
    declare -a rows
    lx db --file "cmds.db" --table "commands" --select @rows --cols "alias,device" --sep " # "
    printf '%s\n' "${rows[@]}"
}

# --- get_all_devices ---
# @desc_short  : Prints all known device names (nodes + containers + VMs), one per line.
# @usage       : get_all_devices
# ==============================================================================
function get_all_devices {
    get_nodes                               # physical nodes (hosts + observers)
    get_containers                          # live containers
    get_vms                                 # live VMs
}

# ==============================================================================
# --- SSH Helpers ---
# Functions for resolving device connection details and executing remote commands.
# ==============================================================================

# --- get_device_ip ---
# @desc_short  : Resolves a device name to its IP address.
# @usage       : get_device_ip <device>
# @parameter   : $1 | device | Logical device name (e.g. host_1, observer_2).
# @notes       : Config-driven — adding a new device only requires updating config.conf
#                (HOSTS/OBSERVERS array + IP_HOST_x / IP_OBSERVER_x variable).
#                Uses indirect variable expansion: HOSTS[0]="host_1" → var="IP_HOST_1" → ${!var}
# ==============================================================================
function get_device_ip {
    local device="$1"

    # Search HOSTS array; index i maps to IP_HOST_$(i+1) via indirect expansion
    for i in "${!HOSTS[@]}"; do
        if [[ "${HOSTS[$i]}" == "$device" ]]; then
            local var="IP_HOST_$((i+1))"
            echo "${!var}"
            return 0
        fi
    done

    # Search OBSERVERS array; index i maps to IP_OBSERVER_$(i+1) via indirect expansion
    for i in "${!OBSERVERS[@]}"; do
        if [[ "${OBSERVERS[$i]}" == "$device" ]]; then
            local var="IP_OBSERVER_$((i+1))"
            echo "${!var}"
            return 0
        fi
    done

    ERROR "Unknown device: '${device}'"
    return 1
}

# --- get_device_ssh_user ---
# @desc_short  : Resolves the SSH user for a given device.
# @usage       : get_device_ssh_user <device>
# @parameter   : $1 | device | Logical device name.
# @notes       : User is determined by device type (host → SSH_USER_HOST,
#                observer → SSH_USER_OBSERVER), both defined in config.conf.
# ==============================================================================
function get_device_ssh_user {
    local device="$1"

    # Check if device is a known host
    for host in "${HOSTS[@]}"; do
        if [[ "$host" == "$device" ]]; then
            echo "$SSH_USER_HOST"
            return 0
        fi
    done

    # Check if device is a known observer
    for observer in "${OBSERVERS[@]}"; do
        if [[ "$observer" == "$device" ]]; then
            echo "$SSH_USER_OBSERVER"
            return 0
        fi
    done

    ERROR "Unknown device: '${device}'"
    return 1
}

# --- execute_on_device ---
# @desc_short  : Executes a command on a remote device via SSH.
# @usage       : execute_on_device <device> <cmd>
# @parameter   : $1 | device | Logical device name.
# @parameter   : $2 | cmd    | Shell command to execute remotely.
# ==============================================================================
function execute_on_device {
    local device="$1"
    local cmd="$2"
    local ip user

    # Resolve device to IP and SSH user
    ip=$(get_device_ip "$device")     || return 1
    user=$(get_device_ssh_user "$device") || return 1

    lx cmd --run "ssh ${user}@${ip} '${cmd}'" --show-cmd
}

# --- find_container_host ---
# @desc_short  : Finds which host is running a given container ID.
# @usage       : find_container_host <container_id>
# @parameter   : $1 | container_id | Proxmox container ID (e.g. 101).
# ==============================================================================
function find_container_host {
    local container_id="$1"
    local ip user

    # Query each host via SSH — return the first one that lists the container ID
    for host in "${HOSTS[@]}"; do
        ip=$(get_device_ip "$host")       || continue
        user=$(get_device_ssh_user "$host") || continue

        if lx cmd --run "ssh ${user}@${ip} 'pct list 2>/dev/null | awk \"NR>1{print \$1}\" | grep -qx ${container_id}'" \
                --quiet --no-error-msg; then
            echo "$host"
            return 0
        fi
    done

    ERROR "Container '${container_id}' not found on any host."
    return 1
}

# --- find_vm_host ---
# @desc_short  : Finds which host is running a given VM ID.
# @usage       : find_vm_host <vm_id>
# @parameter   : $1 | vm_id | Proxmox VM ID (e.g. 201).
# ==============================================================================
function find_vm_host {
    local vm_id="$1"
    local ip user

    # Query each host via SSH — return the first one that lists the VM ID
    for host in "${HOSTS[@]}"; do
        ip=$(get_device_ip "$host")       || continue
        user=$(get_device_ssh_user "$host") || continue

        if lx cmd --run "ssh ${user}@${ip} 'qm list 2>/dev/null | awk \"NR>1{print \$1}\" | grep -qx ${vm_id}'" \
                --quiet --no-error-msg; then
            echo "$host"
            return 0
        fi
    done

    ERROR "VM '${vm_id}' not found on any host."
    return 1
}

# ==============================================================================
# --- Container / VM Execution ---
# Higher-level execute helpers for indirect device access (via host).
# ==============================================================================

# --- execute_on_container ---
# @desc_short  : Executes a command inside a container via 'pct exec' on its host.
# @usage       : execute_on_container <container_id> <cmd>
# @parameter   : $1 | container_id | Proxmox container ID.
# @parameter   : $2 | cmd          | Command to run inside the container.
# ==============================================================================
function execute_on_container {
    local container_id="$1"
    local cmd="$2"
    local host ip user

    # Locate which host is running this container
    host=$(find_container_host "$container_id") || return 1
    ip=$(get_device_ip "$host")                  || return 1
    user=$(get_device_ssh_user "$host")          || return 1

    lx cmd --run "ssh ${user}@${ip} 'pct exec ${container_id} -- ${cmd}'" --show-cmd
}

# --- get_vm_ip ---
# @desc_short  : Resolves a VM's primary IP address via QEMU agent on its host.
# @usage       : get_vm_ip <vm_id>
# @parameter   : $1 | vm_id | Proxmox VM ID.
# @notes       : Requires QEMU guest agent to be running inside the VM.
# ==============================================================================
function get_vm_ip {
    local vm_id="$1"
    local host ip user vm_ip

    host=$(find_vm_host "$vm_id")        || return 1
    ip=$(get_device_ip "$host")           || return 1
    user=$(get_device_ssh_user "$host")   || return 1

    # Query VM's IP via QEMU agent — captures first IP from hostname -I output
    lx cmd --run "ssh ${user}@${ip} 'qm guest exec ${vm_id} -- hostname -I 2>/dev/null'" \
        @vm_ip --quiet --no-error-msg

    # Strip to first IP only (hostname -I may return multiple addresses)
    vm_ip="${vm_ip%% *}"

    if [[ -z "$vm_ip" ]]; then
        ERROR "Could not resolve IP for VM '${vm_id}' — QEMU agent may not be running."
        return 1
    fi

    echo "$vm_ip"
}

# --- execute_on_vm ---
# @desc_short  : Executes a command inside a VM via 'qm guest exec' on its host.
# @usage       : execute_on_vm <vm_id> <cmd>
# @parameter   : $1 | vm_id | Proxmox VM ID.
# @parameter   : $2 | cmd   | Command to run inside the VM.
# @notes       : Requires QEMU guest agent. For file operations use SSH ProxyJump instead.
# ==============================================================================
function execute_on_vm {
    local vm_id="$1"
    local cmd="$2"
    local host ip user

    host=$(find_vm_host "$vm_id")        || return 1
    ip=$(get_device_ip "$host")           || return 1
    user=$(get_device_ssh_user "$host")   || return 1

    lx cmd --run "ssh ${user}@${ip} 'qm guest exec ${vm_id} -- ${cmd}'" --show-cmd
}

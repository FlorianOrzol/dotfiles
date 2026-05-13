#!/bin/bash
# ==============================================================================
# @meta_name        : _fetch.sh
# @desc_short       : Fetch file/directory from device into local mirror.
#                     Sourced by files/main.sh.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"    # common SSH flags

# ==============================================================================
# --- action_fetch ---
# @desc_short  : Fetches a remote file or directory into the local mirror.
#                The device type, device name, and remote path are derived from
#                the provided local mirror path.
# @usage       : action_fetch <local_path>
# @parameter   : $1 | local_path | Full local mirror path (may not exist yet)
# ==============================================================================
function action_fetch {
    local local_path="$1"
    local type device remote_path

    # Derive device type, name, and remote path from the mirror path structure.
    parse_mirror_path "$local_path" type device remote_path

    # Abort if the path is outside the expected mirror structure.
    if [[ -z "$type" || -z "$device" || "$remote_path" == "/" ]]; then
        ERROR "Cannot derive device from path: ${local_path}"
        return 1
    fi

    # Create the local parent directory so tar can extract into it.
    local local_dir
    local_dir="$(dirname "$local_path")"
    mkdir -p "$local_dir"

    INFO "Fetching '${remote_path}' from ${type} '${device}'..."

    # Route to the correct fetch helper based on device type.
    case "$type" in
        observer|host) _fetch_node      "$device" "$remote_path" "$local_dir" ;;
        container)     _fetch_container "$device" "$remote_path" "$local_dir" ;;
        vm)            _fetch_vm        "$device" "$remote_path" "$local_dir" ;;
        # Unknown type indicates a path outside the mirror hierarchy.
        *)             ERROR "Unknown device type '${type}' in path: ${local_path}"; return 1 ;;
    esac || return 1

    OK "Fetched '${remote_path}' → ${local_path}"
}

# --- _fetch_node ---
# @desc_short  : Fetches from observer or host via tar stream over SSH.
# @notes       : Direct SSH/tar — lx cmd cannot handle binary streams.
#                Packs from remote parent dir so archive contains only the basename.
# ==============================================================================
function _fetch_node {
    local device="$1" remote_path="$2" local_dir="$3"
    local ip user

    # Resolve device to IP and SSH user from config.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    # Pack remote file/dir from its parent — stream flows: device → desktop.
    ssh ${SSH_OPTS} "${user}@${ip}" \
        "tar -czf - -C '$(dirname "$remote_path")' '$(basename "$remote_path")'" \
        | tar -xzf - -C "$local_dir"
}

# --- _fetch_container ---
# @desc_short  : Fetches from a container via tar inside pct exec, piped through host SSH.
# @notes       : No direct SSH to containers — stream flows: container → host → desktop.
# ==============================================================================
function _fetch_container {
    local container_id="$1" remote_path="$2" local_dir="$3"
    local host ip user

    # Locate which host is running this container.
    host=$(find_container_host "$container_id") || return 1
    ip=$(get_device_ip "$host")                  || return 1
    user=$(get_device_ssh_user "$host")          || return 1

    # Run tar inside the container via pct exec — stream flows: container → host → desktop.
    ssh ${SSH_OPTS} "${user}@${ip}" \
        "pct exec ${container_id} -- tar -czf - -C '$(dirname "$remote_path")' '$(basename "$remote_path")'" \
        | tar -xzf - -C "$local_dir"
}

# --- _fetch_vm ---
# @desc_short  : Fetches from a VM via tar over SSH ProxyJump through the host.
# @notes       : Requires SSH running in the VM. VM IP resolved via QEMU agent.
#                Stream flows: vm → host → desktop.
# ==============================================================================
function _fetch_vm {
    local vm_id="$1" remote_path="$2" local_dir="$3"
    local host host_ip host_user vm_ip

    # Resolve host and VM connection details.
    host=$(find_vm_host "$vm_id")              || return 1
    host_ip=$(get_device_ip "$host")            || return 1
    host_user=$(get_device_ssh_user "$host")    || return 1
    vm_ip=$(get_vm_ip "$vm_id")                || return 1

    # ProxyJump through host to VM — stream flows: vm → host → desktop.
    ssh ${SSH_OPTS} -J "${host_user}@${host_ip}" "root@${vm_ip}" \
        "tar -czf - -C '$(dirname "$remote_path")' '$(basename "$remote_path")'" \
        | tar -xzf - -C "$local_dir"
}

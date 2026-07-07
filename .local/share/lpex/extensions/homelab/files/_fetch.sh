#!/bin/bash
# ==============================================================================
# @meta_name        : _fetch.sh
# @desc_short       : Fetch a file or directory from a device into the local mirror.
#                     Runs find on the device via SSH, pipes results into FZF for
#                     interactive selection, then fetches the chosen path.
#                     Sourced lazily by files/main.sh when --fetch is used.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"    # common SSH flags

# ==============================================================================
# --- action_fetch ---
# @desc_short  : Entry function for --fetch. SSHes to the device, pipes find output
#                into FZF, confirms, then fetches the selected path into the mirror.
# @notes       : Reads ARG_FETCH (device) and ARG_PATH (base directory) globals.
#                File selection happens here and not via --option-cmd because
#                --option-cmd subprocesses lack the exported SSH routing helpers.
# ==============================================================================
function action_fetch {
    local device_input="$ARG_FETCH"
    local base_path="$ARG_PATH"

    # Base path is required before listing — device is guaranteed by main.sh routing.
    [[ -z "$base_path" ]] && { ERROR "No base path specified. Use --path <dir>."; return 1; }

    local type device_id

    # 1. --- Derive type and device ID from the prefixed device name ----------

    # ct/vm names carry an ID suffix; host/observer names are used as-is.
    case "$device_input" in
        ct_*)        type="ct";       device_id="${device_input#ct_}" ;;
        vm_*)        type="vm";       device_id="${device_input#vm_}" ;;
        host_*)      type="host";     device_id="$device_input" ;;
        observer_*)  type="observer"; device_id="$device_input" ;;
        *)  ERROR "Unknown device: '${device_input}' — expected host_*, observer_*, ct_*, or vm_*"
            return 1 ;;
    esac

    # 2. --- Run find on device and open FZF for interactive selection --------

    INFO "Listing '${base_path}' on ${device_input} ..."

    local file_list selected_file

    # Fetch the remote file listing — all SSH helpers are available here.
    file_list=$(_fetch_find_on_device "$type" "$device_id" "$base_path")

    # No results — device unreachable or path empty.
    if [[ -z "$file_list" ]]; then
        ERROR "No files found at '${base_path}' on ${device_input} — check path and connectivity."
        return 1
    fi

    # Open FZF with remote listing — --confirm asks "Korrekt?" after selection.
    lx fzf @selected_file \
        --list "$file_list" \
        --header "Fetch from ${device_input}:${base_path}" \
        --prompt "fetch > " \
        --standard \
        --confirm

    # User cancelled FZF or declined confirmation — abort silently.
    if [[ -z "$selected_file" ]]; then
        INFO "Aborted."
        return 0
    fi

    # 3. --- Derive mirror path and fetch --------------------------------------

    local mirror_dir mirror_path local_dir remote_parent remote_basename

    # Map device type to mirror subdirectory.
    # Unified types (host, observer) share one mirror — no per-device subdirectory.
    case "$type" in
        ct)       mirror_dir="client/ct/${device_id}" ;;
        vm)       mirror_dir="client/vm/${device_id}" ;;
        host)     mirror_dir="host" ;;
        observer) mirror_dir="observer" ;;
    esac

    # Build the full local mirror path for the selected remote file.
    mirror_path="${PATH_EXTENSION_DATA}/mirror/${mirror_dir}${selected_file}"
    local_dir="$(dirname "$mirror_path")"

    # Split remote path for tar -C usage.
    remote_parent="$(dirname "$selected_file")"
    remote_basename="$(basename "$selected_file")"

    # Create local mirror directory before extracting.
    mkdir -p "$local_dir" || { ERROR "Cannot create mirror directory: ${local_dir}"; return 1; }

    INFO "Fetching ${device_input}:${selected_file} → ${mirror_path} ..."

    # Route to the correct fetch helper based on device type.
    case "$type" in
        observer|host) _fetch_node      "$device_id" "$remote_parent" "$remote_basename" "$local_dir" ;;
        ct)            _fetch_container "$device_id" "$remote_parent" "$remote_basename" "$local_dir" ;;
        vm)            _fetch_vm        "$device_id" "$remote_parent" "$remote_basename" "$local_dir" ;;
    esac || return 1

    OK "Fetched ${device_input}:${selected_file} → ${mirror_path}"
}

# --- _fetch_find_on_device ---
# @desc_short  : Runs find <path> on the target device and streams results to stdout.
# @usage       : _fetch_find_on_device <type> <device_id> <path>
# @parameter   : $1 | type      | Device type: host | observer | ct | vm
# @parameter   : $2 | device_id | Device name or container/VM ID
# @parameter   : $3 | path      | Remote directory to search recursively
# ==============================================================================
function _fetch_find_on_device {
    local type="$1" device_id="$2" path="$3"
    local host ip user

    # Route the find call based on device type — containers and VMs go through their host.
    case "$type" in
        observer|host)
            # Resolve connection details and stream find output directly.
            ip=$(get_device_ip "$device_id")         || return 1
            user=$(get_device_ssh_user "$device_id") || return 1
            ssh ${SSH_OPTS} "${user}@${ip}" "find '${path}' 2>/dev/null | sort"
            ;;
        ct)
            # Route through the Proxmox host that runs this container.
            host=$(find_container_host "$device_id") || return 1
            ip=$(get_device_ip "$host")               || return 1
            user=$(get_device_ssh_user "$host")       || return 1
            # pct exec runs find inside the container — output streams through SSH.
            ssh ${SSH_OPTS} "${user}@${ip}" \
                "pct exec ${device_id} -- find '${path}' 2>/dev/null" | sort
            ;;
        vm)
            # ProxyJump through the host to the VM.
            local host_ip host_user vm_ip
            host=$(find_vm_host "$device_id")         || return 1
            host_ip=$(get_device_ip "$host")           || return 1
            host_user=$(get_device_ssh_user "$host")   || return 1
            vm_ip=$(get_vm_ip "$device_id")           || return 1
            ssh ${SSH_OPTS} -J "${host_user}@${host_ip}" "root@${vm_ip}" \
                "find '${path}' 2>/dev/null | sort"
            ;;
    esac
}

# --- _fetch_node ---
# @desc_short  : Fetches from observer or host via tar stream over SSH.
# @parameter   : $1 | device          | Logical device name
# @parameter   : $2 | remote_parent   | Parent directory of the remote path
# @parameter   : $3 | remote_basename | Filename or directory name to fetch
# @parameter   : $4 | local_dir       | Local directory to extract into
# ==============================================================================
function _fetch_node {
    local device="$1" remote_parent="$2" remote_basename="$3" local_dir="$4"
    local ip user

    # Resolve device to IP and SSH user from config.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    # Stream tar archive from remote path into local mirror.
    ssh ${SSH_OPTS} "${user}@${ip}" \
        "tar -czf - -C '${remote_parent}' '${remote_basename}' 2>/dev/null" \
        | tar -xzf - -C "$local_dir"
}

# --- _fetch_container ---
# @desc_short  : Fetches from a container via pct exec tar stream through the host.
# @parameter   : $1 | container_id    | Proxmox container ID
# @parameter   : $2 | remote_parent   | Parent directory of the remote path
# @parameter   : $3 | remote_basename | Filename or directory name to fetch
# @parameter   : $4 | local_dir       | Local directory to extract into
# ==============================================================================
function _fetch_container {
    local container_id="$1" remote_parent="$2" remote_basename="$3" local_dir="$4"
    local host ip user

    # Locate which host is running this container.
    host=$(find_container_host "$container_id") || return 1
    ip=$(get_device_ip "$host")                  || return 1
    user=$(get_device_ssh_user "$host")          || return 1

    # pct exec runs tar inside the container — its stdout flows through SSH to local tar.
    ssh ${SSH_OPTS} "${user}@${ip}" \
        "pct exec ${container_id} -- tar -czf - -C '${remote_parent}' '${remote_basename}'" \
        | tar -xzf - -C "$local_dir"
}

# --- _fetch_vm ---
# @desc_short  : Fetches from a VM via tar stream over SSH ProxyJump through the host.
# @parameter   : $1 | vm_id           | Proxmox VM ID
# @parameter   : $2 | remote_parent   | Parent directory of the remote path
# @parameter   : $3 | remote_basename | Filename or directory name to fetch
# @parameter   : $4 | local_dir       | Local directory to extract into
# ==============================================================================
function _fetch_vm {
    local vm_id="$1" remote_parent="$2" remote_basename="$3" local_dir="$4"
    local host host_ip host_user vm_ip

    # Resolve host and VM connection details.
    host=$(find_vm_host "$vm_id")           || return 1
    host_ip=$(get_device_ip "$host")         || return 1
    host_user=$(get_device_ssh_user "$host") || return 1
    vm_ip=$(get_vm_ip "$vm_id")             || return 1

    # ProxyJump through host to VM — stream tar archive to local extraction.
    ssh ${SSH_OPTS} -J "${host_user}@${host_ip}" "root@${vm_ip}" \
        "tar -czf - -C '${remote_parent}' '${remote_basename}' 2>/dev/null" \
        | tar -xzf - -C "$local_dir"
}

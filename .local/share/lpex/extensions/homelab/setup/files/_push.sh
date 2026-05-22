#!/bin/bash
# ==============================================================================
# @meta_name        : _push.sh
# @desc_short       : Push local mirror file/directory to device.
#                     Sourced by files/main.sh.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"    # common SSH flags

# ==============================================================================
# --- action_push ---
# @desc_short  : Pushes a local mirror file or directory to the target device.
#                The device type, device name, and remote path are derived from
#                the provided local mirror path.
#                For directories: adds new files, overwrites existing — remote-only files untouched.
#                Ownership on device: root (via sudo). Permissions (+x etc.) preserved from source.
# @usage       : action_push <local_path>
# @parameter   : $1 | local_path | Full local mirror path of the file/directory to push
# ==============================================================================
function action_push {
    local local_path="$1"
    local type device remote_path

    # Local path must exist before attempting to push.
    if [[ ! -e "$local_path" ]]; then
        ERROR "Local path not found: ${local_path}"
        return 1
    fi

    # Derive device type, name, and remote path from the mirror path structure.
    parse_mirror_path "$local_path" type device remote_path

    # Abort if the path is outside the expected mirror structure.
    if [[ -z "$type" || -z "$device" || "$remote_path" == "/" ]]; then
        ERROR "Cannot derive device from path: ${local_path}"
        return 1
    fi

    # Remote directory is the parent of the remote path — must exist before extraction.
    local remote_dir
    remote_dir="$(dirname "$remote_path")"

    INFO "Pushing '${local_path}' → ${type} '${device}':${remote_path}..."

    # Route to the correct push helper based on device type.
    case "$type" in
        observer|host) _push_node      "$device" "$local_path" "$remote_dir" ;;
        container)     _push_container "$device" "$local_path" "$remote_dir" ;;
        vm)            _push_vm        "$device" "$local_path" "$remote_dir" ;;
        # Unknown type indicates a path outside the mirror hierarchy.
        *)             ERROR "Unknown device type '${type}' in path: ${local_path}"; return 1 ;;
    esac || return 1

    # Shell scripts must be executable on the device — set +x after push.
    if [[ "$local_path" == *.sh ]]; then
        INFO "Setting +x on '${remote_path}'..."
        _push_chmod "$type" "$device" "$remote_path"
    fi

    # Systemd template scripts trigger unit regeneration after being pushed.
    if [[ "$remote_path" == */systemd/*.sh ]]; then
        INFO "Systemd template detected — triggering generate-units.sh..."
        _push_generate_units "$type" "$device"
    fi

    OK "Pushed '${local_path}' → ${type} '${device}':${remote_path}"
}

# --- _push_node ---
# @desc_short  : Pushes to observer or host via tar stream over SSH.
# @notes       : Direct SSH/tar — lx cmd cannot handle binary streams.
#                sudo tar: allows writing to privileged paths (/etc/, /opt/ etc.).
#                --no-same-owner: ownership set by root (extractor), not from local uid 1000.
#                For hosts (SSH as root), sudo is a no-op.
# ==============================================================================
function _push_node {
    local device="$1" local_path="$2" remote_dir="$3"
    local ip user sudo_prefix

    # Resolve device to IP and SSH user from config.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    # Root SSH users (hosts) do not need sudo — observers (fadmin) do.
    [[ "$user" == "root" ]] && sudo_prefix="" || sudo_prefix="sudo "

    # Pack from parent dir so archive contains only the basename (file or dir).
    tar -czf - -C "$(dirname "$local_path")" "$(basename "$local_path")" \
        | ssh ${SSH_OPTS} "${user}@${ip}" \
            "${sudo_prefix}mkdir -p '${remote_dir}' && ${sudo_prefix}tar -xzf - -C '${remote_dir}' --no-same-owner"
}

# --- _push_container ---
# @desc_short  : Pushes to a container via host intermediary using pct push + pct exec.
# @notes       : Workflow: tar locally → upload to /tmp on host → pct push into container →
#                pct exec tar extract → cleanup. pct exec runs as root → correct ownership.
# ==============================================================================
function _push_container {
    local container_id="$1" local_path="$2" remote_dir="$3"
    local host ip user
    local tmp_file="/tmp/lpex_push_${container_id}_$$"  # unique temp path per process

    # Locate which host is running this container.
    host=$(find_container_host "$container_id") || return 1
    ip=$(get_device_ip "$host")                  || return 1
    user=$(get_device_ssh_user "$host")          || return 1

    # Single SSH session: receive tar → pct push into container → extract → cleanup.
    tar -czf - -C "$(dirname "$local_path")" "$(basename "$local_path")" \
        | ssh ${SSH_OPTS} "${user}@${ip}" "
            cat > ${tmp_file}.tar
            pct push ${container_id} ${tmp_file}.tar ${tmp_file}.tar
            pct exec ${container_id} -- mkdir -p '${remote_dir}'
            pct exec ${container_id} -- tar -xzf ${tmp_file}.tar -C '${remote_dir}' --no-same-owner
            pct exec ${container_id} -- rm -f ${tmp_file}.tar
            rm -f ${tmp_file}.tar"
}

# --- _push_vm ---
# @desc_short  : Pushes to a VM via tar stream over SSH ProxyJump through the host.
# @notes       : Requires SSH running in the VM. VM IP resolved via QEMU agent.
#                sudo tar: allows writing to privileged paths.
#                --no-same-owner: ownership set by root, not from local uid 1000.
# ==============================================================================
function _push_vm {
    local vm_id="$1" local_path="$2" remote_dir="$3"
    local host host_ip host_user vm_ip

    # Resolve host and VM connection details.
    host=$(find_vm_host "$vm_id")           || return 1
    host_ip=$(get_device_ip "$host")         || return 1
    host_user=$(get_device_ssh_user "$host") || return 1
    vm_ip=$(get_vm_ip "$vm_id")             || return 1

    # ProxyJump through host to VM — pack from parent dir, extract as root.
    tar -czf - -C "$(dirname "$local_path")" "$(basename "$local_path")" \
        | ssh ${SSH_OPTS} -J "${host_user}@${host_ip}" "root@${vm_ip}" \
            "mkdir -p '${remote_dir}' && tar -xzf - -C '${remote_dir}' --no-same-owner"
}

# --- _push_chmod ---
# @desc_short  : Sets +x on the pushed file on the target device.
# ==============================================================================
function _push_chmod {
    local type="$1" device="$2" path="$3"

    # Route chmod to the correct execute helper based on device type.
    case "$type" in
        observer|host) execute_on_device    "$device" "chmod +x '${path}'" ;;
        container)     execute_on_container "$device" "chmod +x '${path}'" ;;
        vm)            execute_on_vm        "$device" "chmod +x '${path}'" ;;
    esac
}

# --- _push_generate_units ---
# @desc_short  : Triggers systemd unit regeneration after a template script was pushed.
# ==============================================================================
function _push_generate_units {
    local type="$1" device="$2"

    # Hosts SSH as root — no sudo needed. Observers SSH as fadmin — sudo required.
    case "$type" in
        host)      execute_on_device    "$device" "/opt/homelab/systemd/generate-units.sh" ;;
        observer)  execute_on_device    "$device" "sudo /opt/homelab/systemd/generate-units.sh" ;;
        container) execute_on_container "$device" "/opt/homelab/systemd/generate-units.sh" ;;
        vm)        execute_on_vm        "$device" "/opt/homelab/systemd/generate-units.sh" ;;
    esac
}

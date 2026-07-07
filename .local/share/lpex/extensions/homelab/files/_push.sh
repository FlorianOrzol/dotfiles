#!/bin/bash
# ==============================================================================
# @meta_name        : _push.sh
# @desc_short       : Push full device mirror(s) to device(s).
#                     Ownership on device is inherited from the existing directory
#                     structure — handled by _installer.sh running on the target.
#                     Sourced lazily by files/main.sh when --push is used.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"    # common SSH flags

# Installer script shipped to the device with every push — base64-encoded into
# the remote command string so it can never collide with payload file names.
INSTALLER_B64="$(base64 -w0 "${PATH_EXTENSION}/_installer.sh")"

# ==============================================================================
# --- action_push_devices ---
# @desc_short  : Entry function for --push. Expands 'all' to every device with a
#                mirror directory, resolves each device name to its mirror root
#                path and pushes the full mirror content to the device.
# @usage       : action_push_devices <device...|all>
# @parameter   : $@ | devices | Device names (host_1, ct_3040, ...) or 'all'
# ==============================================================================
function action_push_devices {
    local devices=("$@")
    local device mirror_path any_error=0

    # Expand 'all' to every device with a mirror directory — mixed input like
    # "ct_3040 all" also triggers the full expansion.
    for device in "${devices[@]}"; do
        if [[ "$device" == "all" ]]; then
            _push_collect_all_devices devices || return 1
            break
        fi
    done

    # Push every requested device — continue on error so one failure
    # does not block the remaining devices.
    for device in "${devices[@]}"; do
        # Resolve device name (e.g. ct_3040, host_1) to its local mirror root path.
        resolve_device_to_mirror_path "$device" @mirror_path || { any_error=1; continue; }
        # Pass the device explicitly — unified mirror types do not encode it in the path.
        action_push "$mirror_path" "$device" || { any_error=1; continue; }
        # Make the observer aware of the deployment — visible in events.log.
        observer_log_event "LPEX: mirror deployed → ${device}" "OK"
    done

    # Report overall failure if any single push failed.
    (( any_error )) && return 1
    return 0
}

# --- _push_collect_all_devices ---
# @desc_short  : Fills the nameref array with every device that has a mirror:
#                all configured hosts and observers (they share the unified
#                mirrors) plus every client mirror directory (ct_<id>, vm_<id>).
# @usage       : _push_collect_all_devices <nameref_devices>
# @parameter   : $1 | nameref_devices | Array variable to receive the device names
# ==============================================================================
function _push_collect_all_devices {
    local -n return_push_collect_all_devices="$1"
    return_push_collect_all_devices=()

    local name
    # All configured hosts — each receives the shared host mirror.
    while IFS= read -r name; do
        [[ -n "$name" ]] && return_push_collect_all_devices+=("$name")
    done < <(get_hosts | awk '{print $1}')

    # All configured observers — each receives the shared observer mirror.
    while IFS= read -r name; do
        [[ -n "$name" ]] && return_push_collect_all_devices+=("$name")
    done < <(get_observers | awk '{print $1}')

    local dir subtype
    # Every client mirror directory maps to one device: client/<subtype>/<id> → <subtype>_<id>.
    while IFS= read -r dir; do
        subtype="$(basename "$(dirname "$dir")")"
        return_push_collect_all_devices+=("${subtype}_$(basename "$dir")")
    done < <(find "${PATH_EXTENSION_DATA}/mirror/client" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort)

    # Abort when nothing was collected — no configured devices and no client mirrors.
    if (( ${#return_push_collect_all_devices[@]} == 0 )); then
        ERROR "No devices with mirror directories found."
        return 1
    fi

    INFO "Pushing to all devices: ${return_push_collect_all_devices[*]}"
}

# ==============================================================================
# --- action_push ---
# @desc_short  : Pushes a local mirror file or directory to the target device.
#                The device type and remote path are derived from the mirror path.
#                For unified types (host, observer), the device name must be supplied
#                explicitly via $2 because it is not encoded in the unified mirror path.
#                For directories: adds new files, overwrites existing — remote-only files untouched.
#                Ownership on device: inherited from the target directory structure
#                (missing dirs inherit from their parent, files from their directory).
#                Permissions (+x etc.) preserved from source.
# @usage       : action_push <local_path> [device]
# @parameter   : $1 | local_path      | Full local mirror path of the file/directory to push
# @parameter   : $2 | device_override | Target device name (required for unified mirror types)
# ==============================================================================
function action_push {
    local local_path="$1"
    local device_override="${2:-}"  # explicit device — required when path does not encode it
    local type device remote_path

    # Local path must exist before attempting to push.
    if [[ ! -e "$local_path" ]]; then
        ERROR "Local path not found: ${local_path}"
        return 1
    fi

    # Derive device type, name, and remote path from the mirror path structure.
    parse_mirror_path "$local_path" type device remote_path

    # For unified mirror types the path does not encode a device — use the explicit parameter.
    [[ -z "$device" && -n "$device_override" ]] && device="$device_override"

    # Abort if the path is outside the expected mirror structure.
    if [[ -z "$type" || -z "$device" ]]; then
        ERROR "Cannot derive device from path: ${local_path}"
        return 1
    fi

    # Device root push: push all top-level entries of the mirror to the device.
    if [[ "$remote_path" == "/" ]]; then
        INFO "Pushing entire device mirror '${local_path}' → ${type} '${device}':/ ..."
        _push_device_root "$type" "$device" "$local_path" || return 1
        OK "Pushed entire device mirror → ${type} '${device}':/"
        return 0
    fi

    # Remote directory is the parent of the remote path — created by the installer
    # with inherited ownership if missing.
    local remote_dir
    remote_dir="$(dirname "$remote_path")"

    INFO "Pushing '${local_path}' → ${type} '${device}':${remote_path}..."

    # Route to the correct push helper based on device type.
    case "$type" in
        observer|host)   _push_node      "$device" "$local_path" "$remote_dir" ;;
        ct|container)    _push_container "$device" "$local_path" "$remote_dir" ;;  # ct = pct push via host
        vm)              _push_vm        "$device" "$local_path" "$remote_dir" ;;
        # Unknown type indicates a path outside the mirror hierarchy.
        *)               ERROR "Unknown device type '${type}' in path: ${local_path}"; return 1 ;;
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

# --- _push_device_root ---
# @desc_short  : Pushes all top-level entries of a device mirror to the device.
#                Iterates each immediate child and delegates to action_push.
#                Triggers generate-units.sh once at the end if any systemd template was pushed.
# ==============================================================================
function _push_device_root {
    local type="$1" device="$2" local_root="$3"
    local any_error=0 has_systemd=0
    local entry

    # Push each immediate child of the mirror root — device is passed down
    # because unified mirror types do not encode it in the path.
    for entry in "$local_root"/*/; do
        entry="${entry%/}"
        # Skip the unexpanded glob when the mirror root is empty.
        [[ -e "$entry" ]] || continue
        action_push "$entry" "$device" || any_error=1
        # Track whether any systemd directory was included — recursive search,
        # because unit templates live nested (e.g. opt/homelab/systemd/).
        find "$entry" -type d -name systemd 2>/dev/null | grep -q . && has_systemd=1
    done

    # Trigger generate-units.sh once after all pushes if systemd templates are present.
    if (( has_systemd )); then
        INFO "Systemd templates present — triggering generate-units.sh on ${device}..."
        _push_generate_units "$type" "$device"  # type determines which execute helper to use
    fi

    (( any_error )) && return 1
    return 0
}

# --- _push_node ---
# @desc_short  : Pushes to observer or host via tar stream over SSH.
# @notes       : Direct SSH/tar — lx cmd cannot handle binary streams.
#                sudo: allows writing to privileged paths (/etc/, /opt/ etc.);
#                for hosts (SSH as root) sudo is a no-op.
#                Payload is extracted to a staging dir, then _installer.sh (shipped
#                base64 in the command string) installs it with inherited ownership.
# ==============================================================================
function _push_node {
    local device="$1" local_path="$2" remote_dir="$3"
    local ip user sudo_prefix
    local staging="/tmp/lpex_push_$$"  # unique staging path per process

    # Resolve device to IP and SSH user from config.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    # Root SSH users (hosts) do not need sudo — observers (fadmin) do.
    [[ "$user" == "root" ]] && sudo_prefix="" || sudo_prefix="sudo "

    # Pack from parent dir so archive contains only the basename (file or dir).
    # Remote: extract to staging → run installer (inherited ownership) → cleanup.
    tar -czf - -C "$(dirname "$local_path")" "$(basename "$local_path")" \
        | ssh ${SSH_OPTS} "${user}@${ip}" "
            mkdir -p '${staging}/payload' \
            && echo '${INSTALLER_B64}' | base64 -d > '${staging}/installer.sh' \
            && ${sudo_prefix}tar -xzf - -C '${staging}/payload' --no-same-owner \
            && ${sudo_prefix}bash '${staging}/installer.sh' '${staging}/payload' '${remote_dir}'
            rc=\$?
            ${sudo_prefix}rm -rf '${staging}'
            exit \$rc"
}

# --- _push_container ---
# @desc_short  : Pushes to a container via host intermediary using pct push + pct exec.
# @notes       : Workflow: tar locally → upload to /tmp on host → pct push into container →
#                extract to staging → _installer.sh installs with inherited ownership →
#                cleanup. pct exec runs as root — required for chown in the installer.
# ==============================================================================
function _push_container {
    local container_id="$1" local_path="$2" remote_dir="$3"
    local host ip user
    local tmp_file="/tmp/lpex_push_${container_id}_$$"  # unique temp path per process
    local staging="/tmp/lpex_push_$$"                   # staging path inside the container

    # Locate which host is running this container.
    host=$(find_container_host "$container_id") || return 1
    ip=$(get_device_ip "$host")                  || return 1
    user=$(get_device_ssh_user "$host")          || return 1

    # Single SSH session: receive tar → pct push into container → extract to
    # staging → run installer (inherited ownership) → cleanup on both levels.
    tar -czf - -C "$(dirname "$local_path")" "$(basename "$local_path")" \
        | ssh ${SSH_OPTS} "${user}@${ip}" "
            cat > ${tmp_file}.tar \
            && pct push ${container_id} ${tmp_file}.tar ${tmp_file}.tar \
            && pct exec ${container_id} -- mkdir -p '${staging}/payload' \
            && pct exec ${container_id} -- bash -c \"echo '${INSTALLER_B64}' | base64 -d > '${staging}/installer.sh'\" \
            && pct exec ${container_id} -- tar -xzf ${tmp_file}.tar -C '${staging}/payload' --no-same-owner \
            && pct exec ${container_id} -- bash '${staging}/installer.sh' '${staging}/payload' '${remote_dir}'
            rc=\$?
            pct exec ${container_id} -- rm -rf '${staging}' ${tmp_file}.tar
            rm -f ${tmp_file}.tar
            exit \$rc"
}

# --- _push_vm ---
# @desc_short  : Pushes to a VM via tar stream over SSH ProxyJump through the host.
# @notes       : Requires SSH running in the VM. VM IP resolved via QEMU agent.
#                SSH as root — required for chown in the installer.
#                Payload is extracted to a staging dir, then _installer.sh (shipped
#                base64 in the command string) installs it with inherited ownership.
# ==============================================================================
function _push_vm {
    local vm_id="$1" local_path="$2" remote_dir="$3"
    local host host_ip host_user vm_ip
    local staging="/tmp/lpex_push_$$"  # unique staging path per process

    # Resolve host and VM connection details.
    host=$(find_vm_host "$vm_id")           || return 1
    host_ip=$(get_device_ip "$host")         || return 1
    host_user=$(get_device_ssh_user "$host") || return 1
    vm_ip=$(get_vm_ip "$vm_id")             || return 1

    # ProxyJump through host to VM — pack from parent dir.
    # Remote: extract to staging → run installer (inherited ownership) → cleanup.
    tar -czf - -C "$(dirname "$local_path")" "$(basename "$local_path")" \
        | ssh ${SSH_OPTS} -J "${host_user}@${host_ip}" "root@${vm_ip}" "
            mkdir -p '${staging}/payload' \
            && echo '${INSTALLER_B64}' | base64 -d > '${staging}/installer.sh' \
            && tar -xzf - -C '${staging}/payload' --no-same-owner \
            && bash '${staging}/installer.sh' '${staging}/payload' '${remote_dir}'
            rc=\$?
            rm -rf '${staging}'
            exit \$rc"
}

# --- _push_chmod ---
# @desc_short  : Sets +x on the pushed file on the target device.
# ==============================================================================
function _push_chmod {
    local type="$1" device="$2" path="$3"

    # Route chmod to the correct execute helper based on device type.
    case "$type" in
        observer|host) execute_on_device    "$device" "chmod +x '${path}'" ;;
        ct|container)  execute_on_container "$device" "chmod +x '${path}'" ;;
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
        host)         execute_on_device    "$device" "/opt/homelab/systemd/generate-units.sh" ;;
        observer)     execute_on_device    "$device" "sudo /opt/homelab/systemd/generate-units.sh" ;;
        ct|container) execute_on_container "$device" "/opt/homelab/systemd/generate-units.sh" ;;
        vm)           execute_on_vm        "$device" "/opt/homelab/systemd/generate-units.sh" ;;
    esac
}

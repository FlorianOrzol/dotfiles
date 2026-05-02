#!/bin/bash
# ==============================================================================
# @meta_name        : files/transfer.sh
# @desc_short       : File transfer actions for the files submodule.
#                     Sourced by files/main.sh.
# ==============================================================================

# ==============================================================================
# --- files_push_cmd ---
# @desc_short   : Receives a tar stream on stdin and extracts it on the device.
# @parameter    : $1 | type        | Device type
# @parameter    : $2 | id          | Device ID
# @parameter    : $3 | remote_dir  | Destination directory on the device
# ==============================================================================
function files_push_cmd {
    local type="$1" id="$2" remote_dir="$3"
    local obs_id obs_ip host_id host_ip

    case "$type" in
        observer)
            obs_ip=$(device_ip "observer" "$id") || return 1
            ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                "mkdir -p ${remote_dir@Q} && tar -xzf - -C ${remote_dir@Q}"
            ;;
        host)
            host_ip=$(device_ip "host" "$id") || return 1
            obs_id=$(leader_observer_id)
            obs_ip=$(device_ip "observer" "$obs_id") || return 1
            ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                'mkdir -p ${remote_dir@Q} && tar -xzf - -C ${remote_dir@Q}'"
            ;;
        container)
            host_id=$(host_for_container "$id") || return 1
            host_ip=$(device_ip "host" "$host_id") || return 1
            obs_id=$(leader_observer_id)
            obs_ip=$(device_ip "observer" "$obs_id") || return 1
            # Unpack to /tmp on host, then copy into container via pct push
            ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                'tar -xzf - -C /tmp/lpex_push_$$ && \
                 pct exec ${id} -- mkdir -p ${remote_dir@Q} && \
                 pct push ${id} /tmp/lpex_push_$$/ ${remote_dir} --perms; \
                 rm -rf /tmp/lpex_push_$$'"
            ;;
        vm)
            host_id=$(host_for_container "$id") || return 1
            host_ip=$(device_ip "host" "$host_id") || return 1
            obs_id=$(leader_observer_id)
            obs_ip=$(device_ip "observer" "$obs_id") || return 1
            local -a _vm_ip_r=()
            lx db --file "homelab_conf.db" --table "vms" --select @_vm_ip_r \
                --cols "ip" --where "id='${id}'" --limit 1 2>/dev/null
            local vm_ip="${_vm_ip_r[0]:-}"
            if [[ -z "$vm_ip" ]]; then
                ERROR "No IP found for VM $id in homelab_conf.db — cannot push files."
                return 1
            fi
            ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                'ssh ${_SSH_OPTS[*]} root@${vm_ip} \
                \"mkdir -p ${remote_dir@Q} && tar -xzf - -C ${remote_dir@Q}\"'"
            ;;
        *) ERROR "Unknown device type: $type"; return 1 ;;
    esac
}

# ==============================================================================
# --- action_fetch ---
# @desc_short   : Pulls a file/directory from the device into the local mirror.
# @parameter    : $1 | type        | Device type
# @parameter    : $2 | id          | Device ID
# @parameter    : $3 | mirror_path | Local mirror base path for the device
# ==============================================================================
function action_fetch {
    local type="$1" id="$2" mirror_path="$3"
    local remote_path="$ARG_FETCH"
    local local_dest="${mirror_path}${remote_path}"
    local local_dir obs_id obs_ip host_id host_ip
    local_dir="$(dirname "$local_dest")"

    INFO "Fetching [${remote_path}] from [${type}] ${id}..."
    mkdir -p "$local_dir"

    case "$type" in
        observer)
            obs_ip=$(device_ip "observer" "$id") || return 1
            ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                "tar -czf - ${remote_path@Q}" | tar -xzf - -C "$local_dir"
            ;;
        host)
            host_ip=$(device_ip "host" "$id") || return 1
            obs_id=$(leader_observer_id)
            obs_ip=$(device_ip "observer" "$obs_id") || return 1
            ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                'tar -czf - ${remote_path@Q}'" | tar -xzf - -C "$local_dir"
            ;;
        container)
            host_id=$(host_for_container "$id") || return 1
            host_ip=$(device_ip "host" "$host_id") || return 1
            obs_id=$(leader_observer_id)
            obs_ip=$(device_ip "observer" "$obs_id") || return 1
            ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                'pct exec ${id} -- tar -czf - ${remote_path@Q}'" \
                | tar -xzf - -C "$local_dir"
            ;;
        vm)
            host_id=$(host_for_container "$id") || return 1
            host_ip=$(device_ip "host" "$host_id") || return 1
            obs_id=$(leader_observer_id)
            obs_ip=$(device_ip "observer" "$obs_id") || return 1
            local -a _vm_ip_r=()
            lx db --file "homelab_conf.db" --table "vms" --select @_vm_ip_r \
                --cols "ip" --where "id='${id}'" --limit 1 2>/dev/null
            local vm_ip="${_vm_ip_r[0]:-}"
            if [[ -z "$vm_ip" ]]; then
                ERROR "No IP found for VM $id in homelab_conf.db — cannot fetch files."
                return 1
            fi
            ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" \
                "ssh ${_SSH_OPTS[*]} ${SSH_USER_HOST}@${host_ip} \
                'ssh ${_SSH_OPTS[*]} root@${vm_ip} tar -czf - ${remote_path@Q}'" \
                | tar -xzf - -C "$local_dir"
            ;;
        *) ERROR "Unknown device type: $type"; return 1 ;;
    esac

    OK "Fetched [${remote_path}] → ${local_dest}"
}

# ==============================================================================
# --- action_push ---
# @desc_short   : Pushes a local mirror file/directory to the target device.
#                 After push: chmod +x for .sh files; triggers generate-units.sh
#                 if the file is a systemd template.
# @parameter    : $1 | type        | Device type
# @parameter    : $2 | id          | Device ID
# @parameter    : $3 | mirror_path | Local mirror base path for the device
# ==============================================================================
function action_push {
    local type="$1" id="$2" mirror_path="$3"
    local local_path="$ARG_PUSH"
    local remote_path="${local_path#"$mirror_path"}"
    local remote_dir src_dir src_name
    remote_dir="$(dirname "$remote_path")"
    src_dir="$(dirname "$local_path")"
    src_name="$(basename "$local_path")"

    if [[ ! -e "$local_path" ]]; then
        ERROR "Local path not found: $local_path"
        return 1
    fi

    INFO "Pushing [${local_path}] → [${type}] ${id}:${remote_path}..."

    tar -czf - -C "$src_dir" "$src_name" | files_push_cmd "$type" "$id" "$remote_dir" || return 1

    # Set executable bit on .sh files after push
    if [[ "$local_path" == *.sh ]]; then
        run_on_device "$type" "$id" "chmod +x ${remote_path@Q}" || true
    fi

    # Trigger generate-units.sh if a systemd template was pushed
    if [[ "$remote_path" == */systemd/*.sh ]]; then
        INFO "Unit-Template erkannt — triggere generate-units.sh..."
        run_on_device "$type" "$id" "sudo /opt/homelab/systemd/generate-units.sh" || true
    fi

    OK "Pushed [${local_path}] → [${type}] ${id}:${remote_path}"
}

# ==============================================================================
# --- action_delete ---
# @desc_short   : Deletes a file/directory on the device AND in the local mirror.
# @parameter    : $1 | type        | Device type
# @parameter    : $2 | id          | Device ID
# @parameter    : $3 | mirror_path | Local mirror base path for the device
# ==============================================================================
function action_delete {
    local type="$1" id="$2" mirror_path="$3"
    local local_path="$ARG_DELETE"
    local remote_path="${local_path#"$mirror_path"}"

    INFO "Deleting [${remote_path}] on [${type}] ${id} and in local mirror..."

    if ! run_on_device "$type" "$id" "rm -rf ${remote_path@Q}"; then
        ERROR "Remote delete failed — local mirror NOT removed."
        return 1
    fi

    # Remove from local mirror only after successful remote delete
    rm -rf "$local_path"
    OK "Deleted [${remote_path}] on device and [${local_path}] in mirror."
}

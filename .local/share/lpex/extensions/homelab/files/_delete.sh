#!/bin/bash
# ==============================================================================
# @meta_name        : _delete.sh
# @desc_short       : Delete file/directory on device(s) AND in local mirror.
#                     Sourced lazily by files/main.sh when --delete is used.
# ==============================================================================

# ==============================================================================
# --- action_delete_paths ---
# @desc_short  : Entry function for --delete. Deletes each given mirror path on
#                the device(s) and in the local mirror. For unified mirror types
#                (host, observer) the deletion is applied to every device of that
#                type so all devices stay in sync with the shared mirror.
# @usage       : action_delete_paths <mirror_path...>
# @parameter   : $@ | paths | Full local mirror paths of the entries to delete
# ==============================================================================
function action_delete_paths {
    local paths=("$@")
    local local_path

    # Process each requested path — abort on first failure to avoid
    # leaving devices of a unified type in an inconsistent state.
    for local_path in "${paths[@]}"; do
        _delete_dispatch "$local_path" || return 1
    done
}

# --- _delete_dispatch ---
# @desc_short  : Deletes one mirror path — fans out to all devices of the type
#                for unified mirrors, single delete for per-device mirrors.
# @parameter   : $1 | local_path | Full local mirror path of the entry to delete
# ==============================================================================
function _delete_dispatch {
    local local_path="$1"
    local type _device _remote

    # Derive the device type — it decides between fan-out and single delete.
    parse_mirror_path "$local_path" type _device _remote

    if _is_unified_mirror_type "$type"; then
        # Unified mirror — apply deletion to every device of this type so all stay in sync.
        local devices=() dev
        case "$type" in
            host)     devices=("${HOSTS[@]}") ;;
            observer) devices=("${OBSERVERS[@]}") ;;
        esac
        for dev in "${devices[@]}"; do
            action_delete "$local_path" "$dev" || return 1
        done
    else
        # Per-device mirror — device is encoded in the path.
        action_delete "$local_path"
    fi
}

# ==============================================================================
# --- action_delete ---
# @desc_short  : Deletes a single file or directory on the device and in the local mirror.
#                The device type and remote path are derived from the mirror path.
#                For unified types (host, observer), the device must be supplied explicitly
#                via $2 because it is not encoded in the path.
#                Remote delete must succeed before the local mirror is touched.
# @usage       : action_delete <local_path> [device]
# @parameter   : $1 | local_path | Full local mirror path of the entry to delete
# @parameter   : $2 | device     | Target device name (required for unified mirror types)
# ==============================================================================
function action_delete {
    local local_path="$1"
    local explicit_device="${2:-}"
    local type device remote_path

    # Derive device type, name, and remote path from the mirror path structure.
    parse_mirror_path "$local_path" type device remote_path

    # For unified mirror types the path does not encode a device — use the explicit parameter.
    [[ -z "$device" && -n "$explicit_device" ]] && device="$explicit_device"

    # Abort if the path is outside the expected mirror structure.
    if [[ -z "$type" || -z "$device" || "$remote_path" == "/" ]]; then
        ERROR "Cannot derive device from path: ${local_path}"
        return 1
    fi

    INFO "Deleting '${remote_path}' on ${type} '${device}' and in local mirror..."

    # Remote delete must succeed — do not remove local mirror entry on failure.
    if ! _delete_on_device "$type" "$device" "$remote_path"; then
        ERROR "Remote delete failed for '${remote_path}' — local mirror NOT removed."
        return 1
    fi

    # Remove local mirror entry only after confirmed remote deletion.
    rm -rf "$local_path"
    OK "Deleted '${remote_path}' on device and '${local_path}' in mirror."
}

# --- _delete_on_device ---
# @desc_short  : Executes rm -rf for the given path on the target device.
# @parameter   : $1 | type   | Device type: host | observer | container | vm
# @parameter   : $2 | device | Device name or ID
# @parameter   : $3 | path   | Remote path to delete
# ==============================================================================
function _delete_on_device {
    local type="$1" device="$2" path="$3"

    # Route to the correct execute helper based on device type.
    case "$type" in
        observer|host) execute_on_device    "$device" "rm -rf '${path}'" ;;
        ct|container)  execute_on_container "$device" "rm -rf '${path}'" ;;
        vm)            execute_on_vm        "$device" "rm -rf '${path}'" ;;
        # Unknown type indicates a path outside the mirror hierarchy.
        *)             ERROR "Unknown device type: '${type}'"; return 1 ;;
    esac
}

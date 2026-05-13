#!/bin/bash
# ==============================================================================
# @meta_name        : _delete.sh
# @desc_short       : Delete file/directory on device AND in local mirror.
#                     Sourced by files/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_delete ---
# @desc_short  : Deletes a single file or directory on the device and in the local mirror.
#                The device type, device name, and remote path are derived from the
#                provided local mirror path. Remote delete must succeed before the
#                local mirror is touched. Iteration over multiple paths is done in main.sh.
# @usage       : action_delete <local_path>
# @parameter   : $1 | local_path | Full local mirror path of the entry to delete
# ==============================================================================
function action_delete {
    local local_path="$1"
    local type device remote_path

    # Derive device type, name, and remote path from the mirror path structure.
    parse_mirror_path "$local_path" type device remote_path

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
        container)     execute_on_container "$device" "rm -rf '${path}'" ;;
        vm)            execute_on_vm        "$device" "rm -rf '${path}'" ;;
        # Unknown type indicates a path outside the mirror hierarchy.
        *)             ERROR "Unknown device type: '${type}'"; return 1 ;;
    esac
}

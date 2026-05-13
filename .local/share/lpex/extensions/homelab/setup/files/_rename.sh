#!/bin/bash
# ==============================================================================
# @meta_name        : _rename.sh
# @desc_short       : Rename file/directory on device AND in local mirror.
#                     Sourced by files/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_rename ---
# @desc_short  : Renames a file or directory on the device and in the local mirror.
#                The device type, device name, and remote path are derived from the
#                provided local mirror path. Remote rename must succeed before the
#                local mirror is touched.
# @usage       : action_rename <local_path>
# @parameter   : $1 | local_path | Full local mirror path of the entry to rename
# ==============================================================================
function action_rename {
    local local_path="$1"
    local new_name="$ARG_RENAME_TO"
    local type device remote_path

    # Local path must exist — cannot rename something not present in the mirror.
    if [[ ! -e "$local_path" ]]; then
        ERROR "Local path not found: ${local_path}"
        return 1
    fi

    # New name is required — provided via --rename-to.
    if [[ -z "$new_name" ]]; then
        ERROR "New name not provided. Use --rename-to <new_name>."
        return 1
    fi

    # Derive device type, name, and remote path from the mirror path structure.
    parse_mirror_path "$local_path" type device remote_path

    # Abort if the path is outside the expected mirror structure.
    if [[ -z "$type" || -z "$device" || "$remote_path" == "/" ]]; then
        ERROR "Cannot derive device from path: ${local_path}"
        return 1
    fi

    # Build the new remote path by replacing the basename in the same remote directory.
    local remote_dir
    remote_dir="$(dirname "$remote_path")"
    local new_remote_path="${remote_dir}/${new_name}"

    # Build the new local mirror path by replacing the basename under the same mirror directory.
    local mirror_base="${PATH_EXTENSION_DATA}/mirror/${type}/${device}"
    local new_local_path="${mirror_base}${new_remote_path}"

    INFO "Renaming '${remote_path}' → '${new_remote_path}' on ${type} '${device}'..."

    # Remote rename must succeed — do not rename local mirror entry on failure.
    if ! _rename_on_device "$type" "$device" "$remote_path" "$new_remote_path"; then
        ERROR "Remote rename failed — local mirror NOT renamed."
        return 1
    fi

    # Rename local mirror entry only after confirmed remote rename.
    mv "$local_path" "$new_local_path"
    OK "Renamed '$(basename "$remote_path")' → '${new_name}' on device and in mirror."
}

# --- _rename_on_device ---
# @desc_short  : Executes mv for the given paths on the target device.
# @parameter   : $1 | type     | Device type: host | observer | container | vm
# @parameter   : $2 | device   | Device name or ID
# @parameter   : $3 | old_path | Current remote path
# @parameter   : $4 | new_path | New remote path
# ==============================================================================
function _rename_on_device {
    local type="$1" device="$2" old_path="$3" new_path="$4"

    # Route to the correct execute helper based on device type.
    case "$type" in
        observer|host) execute_on_device    "$device" "mv '${old_path}' '${new_path}'" ;;
        container)     execute_on_container "$device" "mv '${old_path}' '${new_path}'" ;;
        vm)            execute_on_vm        "$device" "mv '${old_path}' '${new_path}'" ;;
        # Unknown type indicates a path outside the mirror hierarchy.
        *)             ERROR "Unknown device type: '${type}'"; return 1 ;;
    esac
}

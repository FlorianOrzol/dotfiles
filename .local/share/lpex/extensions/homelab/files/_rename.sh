#!/bin/bash
# ==============================================================================
# @meta_name        : _rename.sh
# @desc_short       : Rename file/directory on device(s) AND in local mirror.
#                     Sourced lazily by files/main.sh when --rename is used.
# ==============================================================================

# ==============================================================================
# --- action_rename_entry ---
# @desc_short  : Entry function for --rename. Renames the given mirror path on
#                the device(s) and in the local mirror. For unified mirror types
#                (host, observer) the rename is applied to every device of that
#                type; the local mirror entry is renamed only once (last device).
# @usage       : action_rename_entry <mirror_path>
# @parameter   : $1 | local_path | Full local mirror path of the entry to rename
# @notes       : The new name comes from the ARG_RENAME_TO global (--rename-to).
# ==============================================================================
function action_rename_entry {
    local local_path="$1"

    # New name is required — provided via --rename-to.
    [[ -z "$ARG_RENAME_TO" ]] && { ERROR "No new name specified. Use --rename-to <name>."; return 1; }

    local type _device _remote

    # Derive the device type — it decides between fan-out and single rename.
    parse_mirror_path "$local_path" type _device _remote

    if _is_unified_mirror_type "$type"; then
        # Unified mirror — apply rename to every device of this type so all stay in sync.
        # Local mirror entry is renamed only on the last iteration (inside action_rename).
        local devices=() dev last_dev
        case "$type" in
            host)     devices=("${HOSTS[@]}") ;;
            observer) devices=("${OBSERVERS[@]}") ;;
        esac
        last_dev="${devices[-1]}"
        for dev in "${devices[@]}"; do
            if [[ "$dev" == "$last_dev" ]]; then
                # Last device also renames the local mirror entry.
                action_rename "$local_path" "$dev" || return 1
            else
                # Remote only — skip local rename until the last device to avoid renaming twice.
                _rename_on_device "$type" "$dev" "$_remote" "$(dirname "$_remote")/${ARG_RENAME_TO}" || return 1
            fi
        done
    else
        # Per-device mirror — device is encoded in the path.
        action_rename "$local_path"
    fi
}

# ==============================================================================
# --- action_rename ---
# @desc_short  : Renames a file or directory on the device and in the local mirror.
#                The device type and remote path are derived from the mirror path.
#                For unified types (host, observer), the device must be supplied
#                explicitly via $2 because it is not encoded in the path.
#                Remote rename must succeed before the local mirror is touched.
# @usage       : action_rename <local_path> [device]
# @parameter   : $1 | local_path | Full local mirror path of the entry to rename
# @parameter   : $2 | device     | Target device name (required for unified mirror types)
# ==============================================================================
function action_rename {
    local local_path="$1"
    local explicit_device="${2:-}"
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

    # For unified mirror types the path does not encode a device — use the explicit parameter.
    [[ -z "$device" && -n "$explicit_device" ]] && device="$explicit_device"

    # Abort if the path is outside the expected mirror structure.
    if [[ -z "$type" || -z "$device" || "$remote_path" == "/" ]]; then
        ERROR "Cannot derive device from path: ${local_path}"
        return 1
    fi

    # Build the new remote path by replacing the basename in the same remote directory.
    local remote_dir
    remote_dir="$(dirname "$remote_path")"
    local new_remote_path="${remote_dir}/${new_name}"

    # Build the new local mirror path — unified types have no device subdirectory.
    local mirror_type_dir
    mirror_type_dir=$(get_client_mirror_dir "$type")
    local mirror_base
    if _is_unified_mirror_type "$type"; then
        mirror_base="${PATH_EXTENSION_DATA}/mirror/${mirror_type_dir}"  # shared mirror, no device subdir
    else
        mirror_base="${PATH_EXTENSION_DATA}/mirror/${mirror_type_dir}/${device}"
    fi
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
        ct|container)  execute_on_container "$device" "mv '${old_path}' '${new_path}'" ;;
        vm)            execute_on_vm        "$device" "mv '${old_path}' '${new_path}'" ;;
        # Unknown type indicates a path outside the mirror hierarchy.
        *)             ERROR "Unknown device type: '${type}'"; return 1 ;;
    esac
}

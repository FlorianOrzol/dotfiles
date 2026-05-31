#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Routes file operations. Device type and name are derived
#                     from the local mirror path — no device flag required.
# ==============================================================================

source "${PATH_EXTENSION}/_fetch.sh"
source "${PATH_EXTENSION}/_push.sh"
source "${PATH_EXTENSION}/_delete.sh"
source "${PATH_EXTENSION}/_rename.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates that at least one action was specified, then routes
#                to the appropriate action function(s).
# ==============================================================================
function extension_start {
    local any_error=0

    # Require at least one action — nothing to do otherwise.
    if [[ -z "$ARG_GOTO" && -z "$ARG_FETCH" && -z "$ARG_RENAME" \
          && "${#ARG_PUSH[@]}" -eq 0 && "${#ARG_DELETE[@]}" -eq 0 ]]; then
        ERROR "No action specified. Use --goto, --fetch, --push, --delete, or --rename."
        return 1
    fi

    # --goto: open the selected mirror directory in the terminal.
    [[ -n "$ARG_GOTO" ]] && { action_goto "$ARG_GOTO" || any_error=1; }

    # --fetch: pull a remote path into the local mirror.
    [[ -n "$ARG_FETCH" ]] && { action_fetch "$ARG_FETCH" || any_error=1; }

    # --push: resolve each device name to its mirror root path, then push.
    for device in "${ARG_PUSH[@]}"; do
        local mirror_path
        resolve_device_to_mirror_path "$device" mirror_path || { any_error=1; continue; }
        action_push "$mirror_path" || any_error=1
    done

    # --delete: iterate all selected paths and delete each one from device and mirror.
    for path in "${ARG_DELETE[@]}"; do
        action_delete "$path" || any_error=1
    done

    # --rename: rename the selected path on device and in mirror.
    [[ -n "$ARG_RENAME" ]] && { action_rename "$ARG_RENAME" || any_error=1; }

    # Propagate failure if any action failed.
    (( any_error )) && return 1
    return 0
}

# ==============================================================================
# --- parse_mirror_path ---
# @desc_short  : Extracts device type, device name, and remote path from a local
#                mirror path. Used by all action functions in this submodule.
# @usage       : parse_mirror_path <local_path> <nameref_type> <nameref_device> <nameref_remote>
# @parameter   : $1 | local_path     | Full local mirror path
# @parameter   : $2 | nameref_type   | Variable name to receive the device type
# @parameter   : $3 | nameref_device | Variable name to receive the device name
# @parameter   : $4 | nameref_remote | Variable name to receive the remote path
# @notes       : Mirror structure: ${PATH_EXTENSION_DATA}/mirror/<type>/<device>/remote/path
#                Returns remote="/" when the path points to the mirror base directory.
# ==============================================================================
function parse_mirror_path {
    local full_path="$1"
    local -n _pmp_type="$2"
    local -n _pmp_device="$3"
    local -n _pmp_remote="$4"
    local mirror_root="${PATH_EXTENSION_DATA}/mirror/"

    # Strip the mirror root prefix to obtain the relative path.
    local rel="${full_path#"$mirror_root"}"

    # First path component is the device type (e.g. "host", "container").
    _pmp_type="${rel%%/*}"
    rel="${rel#"${_pmp_type}"}"
    # Strip the separator slash between type and device.
    rel="${rel#/}"

    # "client" is a grouping prefix — extract the subtype (ct/vm) as the effective type
    if [[ "$_pmp_type" == "client" ]]; then
        _pmp_type="${rel%%/*}"  # subtype: "ct" or "vm"
        rel="${rel#"${_pmp_type}"}"
        rel="${rel#/}"
    fi

    # Second path component is the device name or ID.
    _pmp_device="${rel%%/*}"
    rel="${rel#"${_pmp_device}"}"
    # Strip the separator slash between device and the remote path.
    rel="${rel#/}"

    # Remaining string is the remote path — prepend slash, or use "/" if empty.
    if [[ -n "$rel" ]]; then
        _pmp_remote="/${rel}"
    else
        # Path points to the mirror base directory itself — remote root.
        _pmp_remote="/"
    fi
}

# ==============================================================================
# --- resolve_device_to_mirror_path ---
# @desc_short  : Converts a device name to its full local mirror root path.
#                Input format: host_1, observer_2, container_1111, vm_101.
#                Container and VM names carry a type prefix that is stripped.
# @usage       : resolve_device_to_mirror_path <device_name> <nameref_path>
# @parameter   : $1 | device_name  | Device name as used in the CLI (e.g. container_1111)
# @parameter   : $2 | nameref_path | Variable to receive the full mirror root path
# ==============================================================================
function resolve_device_to_mirror_path {
    local device_input="$1"
    local -n return_resolve_device_to_mirror_path="$2"
    local type name

    # Derive type and directory name from the input — ct/vm/container carry an explicit prefix
    case "$device_input" in
        ct_*)        type="ct";        name="${device_input#ct_}" ;;
        vm_*)        type="vm";        name="${device_input#vm_}" ;;
        container_*) type="container"; name="${device_input#container_}" ;;  # legacy flat path
        host_*)      type="host";      name="$device_input" ;;
        observer_*)  type="observer";  name="$device_input" ;;
        *)           ERROR "Cannot resolve device: '${device_input}' — expected host_*, observer_*, ct_*, vm_*, or container_*"
                     return 1 ;;
    esac

    # Map type to its actual mirror subdirectory — client types live under client/
    local mirror_dir
    mirror_dir=$(get_client_mirror_dir "$type")

    local path="${PATH_EXTENSION_DATA}/mirror/${mirror_dir}/${name}"

    # Abort if the mirror directory does not exist — nothing to push
    if [[ ! -d "$path" ]]; then
        ERROR "Mirror directory not found: ${path}"
        return 1
    fi

    return_resolve_device_to_mirror_path="$path"
}

# ==============================================================================
# --- get_client_mirror_dir ---
# @desc_short  : Maps a device type to its mirror subdirectory path.
# @notes       : Client types (ct, vm) live under client/ — all others map 1:1.
# ==============================================================================
function get_client_mirror_dir {
    local type="$1"

    # Return the mirror subdirectory path for the given device type
    case "$type" in
        ct)  echo "client/ct" ;;   # LXC containers live under client/ct/
        vm)  echo "client/vm" ;;   # VMs live under client/vm/
        *)   echo "$type" ;;       # host, observer, container (legacy) map directly
    esac
}

# ==============================================================================
# --- action_goto ---
# @desc_short  : Opens the selected mirror directory in the configured terminal.
# @parameter   : $1 | local_path | Local mirror directory path to open
# ==============================================================================
function action_goto {
    local local_path="$1"

    # Mirror directory must exist — prompt to run --fetch first if not yet populated.
    if [[ ! -d "$local_path" ]]; then
        WARN "Mirror directory does not exist: ${local_path}"
        INFO "Run --fetch first to populate the mirror."
        return 1
    fi

    INFO "Opening mirror: ${local_path}"
    # Open in background so the terminal launch does not block further actions.
    $TERMINAL "$local_path" &
}

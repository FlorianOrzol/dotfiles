#!/bin/bash
# ==============================================================================
# @meta_name        : _common.sh
# @desc_short       : Shared helpers for all files submodules.
#                     Sourced explicitly by each submodule's main.sh.
# ==============================================================================

# Types that share ONE mirror directory across all devices of that type.
# Per-device types (ct, vm, container) keep individual subdirectories.
_UNIFIED_MIRROR_TYPES=("host" "observer")

# ==============================================================================
# --- _is_unified_mirror_type ---
# @desc_short  : Returns 0 if the type uses a shared mirror dir (no per-device subdir).
# @usage       : _is_unified_mirror_type <type>
# ==============================================================================
function _is_unified_mirror_type {
    local t
    for t in "${_UNIFIED_MIRROR_TYPES[@]}"; do
        [[ "$1" == "$t" ]] && return 0
    done
    return 1
}

# ==============================================================================
# --- parse_mirror_path ---
# @desc_short  : Extracts device type, device name, and remote path from a local
#                mirror path. Used by all action functions in this submodule.
# @usage       : parse_mirror_path <local_path> <nameref_type> <nameref_device> <nameref_remote>
# @parameter   : $1 | local_path     | Full local mirror path
# @parameter   : $2 | nameref_type   | Variable name to receive the device type
# @parameter   : $3 | nameref_device | Variable name to receive the device name (empty for unified types)
# @parameter   : $4 | nameref_remote | Variable name to receive the remote path
# @notes       : Unified types (host, observer): mirror/<type>/remote/path — no device subdir.
#                Per-device types (ct, vm):       mirror/client/<type>/<id>/remote/path.
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
    rel="${rel#/}"  # strip separator between type and next component

    # "client" is a grouping prefix — extract the subtype (ct/vm) as the effective type.
    if [[ "$_pmp_type" == "client" ]]; then
        _pmp_type="${rel%%/*}"  # subtype: "ct" or "vm"
        rel="${rel#"${_pmp_type}"}"
        rel="${rel#/}"
    fi

    # Unified types have no device subdirectory — the rest of the path IS the remote path.
    if _is_unified_mirror_type "$_pmp_type"; then
        _pmp_device=""  # device is not encoded in path; caller must supply it externally
        if [[ -n "$rel" ]]; then
            _pmp_remote="/${rel}"
        else
            _pmp_remote="/"
        fi
        return
    fi

    # Per-device types: second path component is the device name or ID.
    _pmp_device="${rel%%/*}"
    rel="${rel#"${_pmp_device}"}"
    rel="${rel#/}"  # strip separator between device and remote path

    # Remaining string is the remote path — prepend slash, or use "/" if empty.
    if [[ -n "$rel" ]]; then
        _pmp_remote="/${rel}"
    else
        # Path points to the mirror base directory itself — remote root.
        _pmp_remote="/"
    fi
}

# ==============================================================================
# --- get_client_mirror_dir ---
# @desc_short  : Maps a device type to its mirror subdirectory path.
# @notes       : Client types (ct, vm) live under client/ — all others map 1:1.
# ==============================================================================
function get_client_mirror_dir {
    local type="$1"

    # Return the mirror subdirectory path for the given device type.
    case "$type" in
        ct)  echo "client/ct" ;;   # LXC containers live under client/ct/
        vm)  echo "client/vm" ;;   # VMs live under client/vm/
        *)   echo "$type" ;;       # host, observer, container (legacy) map directly
    esac
}

# ==============================================================================
# --- resolve_device_to_mirror_path ---
# @desc_short  : Converts a device name to its full local mirror root path.
#                Input format: host_1, observer_2, container_1111, vm_101.
#                Container and VM names carry a type prefix that is stripped.
# @usage       : resolve_device_to_mirror_path <device_name> <nameref_path>
# @parameter   : $1 | device_name  | Device name as used in the CLI (e.g. ct_3040)
# @parameter   : $2 | nameref_path | Variable to receive the full mirror root path
# ==============================================================================
function resolve_device_to_mirror_path {
    local device_input="$1"
    local -n return_resolve_device_to_mirror_path="$2"
    local type name

    # Derive type and directory name from the input — ct/vm/container carry an explicit prefix.
    case "$device_input" in
        ct_*)        type="ct";        name="${device_input#ct_}" ;;
        vm_*)        type="vm";        name="${device_input#vm_}" ;;
        container_*) type="container"; name="${device_input#container_}" ;;
        host_*)      type="host";      name="$device_input" ;;
        observer_*)  type="observer";  name="$device_input" ;;
        *)  ERROR "Cannot resolve device: '${device_input}' — expected host_*, observer_*, ct_*, vm_*, or container_*"
            return 1 ;;
    esac

    # Map type to its actual mirror subdirectory — client types live under client/.
    local mirror_dir
    mirror_dir=$(get_client_mirror_dir "$type")

    local path
    if _is_unified_mirror_type "$type"; then
        # Unified types share one mirror directory — no per-device subdirectory.
        path="${PATH_EXTENSION_DATA}/mirror/${mirror_dir}"
    else
        # Per-device types have individual subdirectories keyed by device name/ID.
        path="${PATH_EXTENSION_DATA}/mirror/${mirror_dir}/${name}"
    fi

    # Abort if the mirror directory does not exist — nothing to push.
    if [[ ! -d "$path" ]]; then
        ERROR "Mirror directory not found: ${path}"
        return 1
    fi

    return_resolve_device_to_mirror_path="$path"
}
